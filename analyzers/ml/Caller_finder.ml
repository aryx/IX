(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Caller_finder.mli *)

let unit_of (file : string) : string = String.capitalize_ascii (Filename.remove_extension (Filename.basename file))

let is_ident (c : char) : bool =
  match c with 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '\'' -> true | _ -> false

(* the word before [i] on its line, after blanks; and whether the line
 * starts with module (module G = TinyLibGUI) *)
let before (text : string) (i : int) : string * bool =
  let k = ref (i - 1) in
  while !k >= 0 && (text.[!k] = ' ' || text.[!k] = '\t') do decr k done;
  let e = !k + 1 in
  while !k >= 0 && (is_ident text.[!k] || text.[!k] = '=') do decr k done;
  let word = String.sub text (!k + 1) (e - !k - 1) in
  let start = ref i in
  while !start > 0 && text.[!start - 1] <> '\n' do decr start done;
  while !start < i && (text.[!start] = ' ' || text.[!start] = '\t') do incr start done;
  (word, String.length text - !start >= 7 && String.sub text !start 7 = "module ")

(* where a comment that starts at [i] ends, its nested ones in it *)
let rec comment_end (text : string) (i : int) : int =
  let n = String.length text in
  let rec go (j : int) : int =
    if j + 1 >= n then n
    else if text.[j] = '*' && text.[j + 1] = ')' then j + 2
    else if text.[j] = '(' && text.[j + 1] = '*' then go (comment_end text j)
    else go (j + 1) in
  go (i + 2)

(* where a string that starts at [i] ends *)
let string_end (text : string) (i : int) : int =
  let n = String.length text in
  let rec go (j : int) : int =
    if j >= n then n else if text.[j] = '\\' then go (j + 2) else if text.[j] = '"' then j + 1 else go (j + 1) in
  go (i + 1)

(* The unit names a text's code uses, each once: a capitalized name
 * before a dot (TinyLibGUI.run), or after open, include, or the = of a
 * module alias (module G = TinyLibGUI). Not a comment's or a string's: a
 * comment's TinyMachine.ml in a unit TinyMachine.ml names would make a
 * cycle, which code cannot, and no main would be found. *)
let names (text : string) : (string, unit) Hashtbl.t =
  let h = Hashtbl.create 64 in
  let n = String.length text in
  let i = ref 0 in
  while !i < n do
    let c = text.[!i] in
    if c = '(' && !i + 1 < n && text.[!i + 1] = '*' then i := comment_end text !i
    else if c = '"' then i := string_end text !i
    (* ('"', '\"': a character, not a string) *)
    else if c = '\'' && !i + 2 < n && text.[!i + 2] = '\'' then i := !i + 3
    else if c = '\'' && !i + 3 < n && text.[!i + 1] = '\\' && text.[!i + 3] = '\'' then i := !i + 4
    else if c >= 'A' && c <= 'Z' && (!i = 0 || not (is_ident text.[!i - 1])) then begin
      let j = ref !i in
      while !j < n && is_ident text.[!j] do incr j done;
      let w = String.sub text !i (!j - !i) in
      let dotted = !j < n && text.[!j] = '.' in
      if dotted then Hashtbl.replace h w ()
      else begin
        match before text !i with
        | ("open" | "include"), _ | "=", true -> Hashtbl.replace h w ()
        | _ -> ()
      end;
      i := !j
    end
    else incr i
  done;
  h

let is_tests (n : string) : bool = n = "tests" || String.ends_with ~suffix:"_tests" n

(* (.git, _build, _mk/7: not sources; tests/, KFS_tests/: the tests',
 * unless the unit is a test's itself, analyzers/tests/'s cases) *)
let skipped (tests : bool) (n : string) : bool =
  n = "" || n.[0] = '.' || n.[0] = '_' || (not tests && is_tests n)

let rec ml_files (caps : < Cap.readdir; .. >) (tests : bool) (d : string) (acc : string list) : string list =
  let entries = try CapSys.readdir caps d with Sys_error _ -> [||] in
  Array.sort compare entries;
  Array.fold_left
    (fun (acc : string list) (n : string) ->
      let p = if d = "." then n else Filename.concat d n in
      if skipped tests n then acc
      else if Filename.check_suffix n ".ml" then p :: acc
      else if (try CapSys.is_directory caps p with Sys_error _ -> false) then ml_files caps tests p acc
      else acc)
    acc entries

let programs (caps : < Cap.open_in; Cap.readdir; .. >) (given : string list) (file : string) : string list =
  match Unit_finder.part_dir caps file with
  | None -> []
  | Some top ->
      let file = FS.cleanname file in
      let given = List.map FS.cleanname given in
      let units =
        List.filter_map
          (fun (f : string) ->
            Option.map (fun (text : string) -> (FS.cleanname f, unit_of f, names text)) (FS.read_opt caps (Fpath.v f)))
          (ml_files caps (List.exists is_tests (String.split_on_char '/' file)) top []) in
      Logs.info (fun m -> m "callers: %d .ml files in %s" (List.length units) top);
      (* (a unit's files, its platforms' when it has several) *)
      let files_of (u : string) : string list =
        List.filter_map (fun ((f, v, _) : string * string * (string, unit) Hashtbl.t) -> if v = u then Some f else None) units in
      (* (one of several files of a unit: the platform's the flags give,
       * if they give one; another file of the unit's name, an
       * implementation of its interface, is not a caller) *)
      let linked (f : string) (u : string) : bool =
        let dir (x : string) = FS.cleanname (Filename.dirname x) in
        let fs = files_of u in
        not (List.exists (fun (x : string) -> List.mem (dir x) given) fs) || List.mem (dir f) given in
      (* (a name is first its own directory's unit: tiny-ml's Types names
       * TinyML/Lexer.ml, not TinyC/Lexer.ml) *)
      let resolves (g : string) (u : string) (fu : string) : bool =
        let d = Filename.dirname g in
        not (List.exists (fun (x : string) -> x <> fu && Filename.dirname x = d) (files_of u)) in
      let namers (fu : string) (u : string) : (string * string) list =
        List.filter_map
          (fun ((f, v, w) : string * string * (string, unit) Hashtbl.t) ->
            if v <> u && Hashtbl.mem w u && linked f v && resolves f u fu then Some (f, v) else None)
          units in
      let seen = Hashtbl.create 64 and mains = ref [] in
      let rec up (f : string) (u : string) : unit =
        if not (Hashtbl.mem seen f) then begin
          Hashtbl.replace seen f ();
          match namers f u with
          | [] -> if f <> file then mains := f :: !mains
          | l ->
              List.iter
                (fun ((g, v) : string * string) ->
                  Logs.debug (fun m -> m "callers: %s names %s" g u);
                  up g v)
                l
        end in
      up file (unit_of file);
      List.sort_uniq compare !mains
