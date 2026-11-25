(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Module_finder.mli *)

(* the project's units: each file name's directories (Lexer.ml, Lexer.mli),
 * each directory's unit names *)
type index = {
  homes : (string, string list) Hashtbl.t;
  names : (string, (string, unit) Hashtbl.t) Hashtbl.t;
}

type t = {
  (* the program's first file, and the project's root once found *)
  first : string;
  mutable root : string;
  (* the index, made on the first unit asked for: None until then, and
   * Some None when there is no project *)
  mutable index : index option option;
  make : unit -> (string * index) option;
  (* the module names the program's files use *)
  needed : (string, unit) Hashtbl.t;
  (* the directories chosen for the program's units so far *)
  chosen : (string, unit) Hashtbl.t;
}

let unit_of (file : string) : string = String.capitalize_ascii (Filename.remove_extension file)

let found (h : (string, 'a list) Hashtbl.t) (k : string) : 'a list =
  match Hashtbl.find_opt h k with Some l -> l | None -> []

let add (h : (string, 'a list) Hashtbl.t) (k : string) (v : 'a) : unit =
  Hashtbl.replace h k (v :: found h k)

(* (.git, _build, _mk/7, _make-x: a checkout's or a build's, not sources) *)
let skipped (n : string) : bool = n = "" || n.[0] = '.' || n.[0] = '_'

let rec walk (caps : < Cap.readdir; .. >) (idx : index) (d : string) : unit =
  let entries = try CapSys.readdir caps d with Sys_error _ -> [||] in
  Array.sort compare entries;
  Array.iter
    (fun (n : string) ->
      let p = if d = "." then n else Filename.concat d n in
      if skipped n then ()
      else if Filename.check_suffix n ".ml" || Filename.check_suffix n ".mli" then begin
        let u = unit_of n and key = String.capitalize_ascii n in
        if not (List.mem d (found idx.homes key)) then add idx.homes key d;
        let names =
          match Hashtbl.find_opt idx.names d with
          | Some h -> h
          | None -> let h = Hashtbl.create 16 in Hashtbl.replace idx.names d h; h in
        Hashtbl.replace names u ()
      end
      else if (try CapSys.is_directory caps p with Sys_error _ -> false) then walk caps idx p)
    entries

(* the project's root, the first directory above [file] with a
 * dune-project, as the files are named: relative to the current
 * directory when under it *)
let root (caps : < Cap.readdir; .. >) (file : string) : string option =
  let cwd = FS.getcwd caps () in
  let absolute = FS.cleanname (if Filename.is_relative file then Filename.concat cwd file else file) in
  let rec up (d : string) : string option =
    if CapSys.file_exists caps (Filename.concat d "dune-project") then Some d
    else if Filename.dirname d = d then None
    else up (Filename.dirname d) in
  match up (Filename.dirname absolute) with
  | None -> None
  | Some r when r = cwd -> Some "."
  | Some r when String.starts_with ~prefix:(cwd ^ "/") r -> Some (String.sub r (String.length cwd + 1) (String.length r - String.length cwd - 1))
  | Some r -> Some r

(* (each project's index, made once in a run: the library's choice and the
 * units' share it) *)
let indexes : (string, index) Hashtbl.t = Hashtbl.create 1

let create (caps : < Cap.readdir; .. >) (file : string) : t =
  let make () : (string * index) option =
    match root caps file with
    | None -> None
    | Some r -> (
        match Hashtbl.find_opt indexes r with
        | Some idx -> Some (r, idx)
        | None ->
            let idx = { homes = Hashtbl.create 1024; names = Hashtbl.create 256 } in
            walk caps idx r;
            Hashtbl.replace indexes r idx;
            Logs.info (fun m -> m "units: the project's at %s, %d names in %d directories" r (Hashtbl.length idx.homes) (Hashtbl.length idx.names));
            Some (r, idx)) in
  { first = file; root = "."; index = None; make; needed = Hashtbl.create 64; chosen = Hashtbl.create 16 }

let index (t : t) : index option =
  match t.index with
  | Some i -> i
  | None ->
      let i = match t.make () with Some (r, idx) -> t.root <- r; Some idx | None -> None in
      t.index <- Some i;
      i

(* the project's top directory a path is in: tiny for tiny/TinyML/Lexer.ml *)
let part (t : t) (p : string) : string =
  let p = FS.cleanname p in
  let rel =
    if t.root = "." then p
    else if String.starts_with ~prefix:(t.root ^ "/") p then String.sub p (String.length t.root + 1) (String.length p - String.length t.root - 1)
    else p in
  match String.split_on_char '/' rel with x :: _ -> x | [] -> ""

let own (t : t) (d : string) : bool = part t d = part t t.first

let part_dir (caps : < Cap.readdir; .. >) (file : string) : string option =
  match root caps file with
  | None -> None
  | Some r ->
      let t = { first = file; root = r; index = None; make = (fun () -> None); needed = Hashtbl.create 1; chosen = Hashtbl.create 1 } in
      let x = part t file in
      (* (a file at the project's top: the whole project) *)
      if x = Filename.basename (FS.cleanname file) then Some r
      else Some (if r = "." then x else Filename.concat r x)

let is_ident (c : char) : bool =
  match c with 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '\'' -> true | _ -> false

(* (a capitalized name before a dot: List.map's List, Lexer.token's Lexer;
 * a comment's or a string's too, which costs only a little precision) *)
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

(* where a quoted string {id|...|id} that starts at [i] ends; None when
 * no such string starts there (a record's {) *)
let quoted_end (text : string) (i : int) : int option =
  let n = String.length text in
  let j = ref (i + 1) in
  while !j < n && (text.[!j] = '_' || (text.[!j] >= 'a' && text.[!j] <= 'z')) do incr j done;
  if !j >= n || text.[!j] <> '|' then None
  else
    let close = "|" ^ String.sub text (i + 1) (!j - i - 1) ^ "}" in
    let k = String.length close in
    let rec go (p : int) : int =
      if p + k > n then n else if String.sub text p k = close then p + k else go (p + 1) in
    Some (go (!j + 1))

(* The unit names a text's code uses, each once: a capitalized name
 * before a dot (TinyLibGUI.run), or after open, include, or the = of a
 * module alias (module G = TinyLibGUI). Not a comment's or a string's: a
 * comment's TinyMachine.ml in a unit TinyMachine.ml names would make a
 * cycle, which code cannot, and no main would be found; nor a quoted
 * string's, a help's {|... -start Unit...|} *)
let names (text : string) : (string, unit) Hashtbl.t =
  let h = Hashtbl.create 64 in
  let n = String.length text in
  let i = ref 0 in
  while !i < n do
    let c = text.[!i] in
    if c = '(' && !i + 1 < n && text.[!i + 1] = '*' then i := comment_end text !i
    else if c = '"' then i := string_end text !i
    else if c = '{' && quoted_end text !i <> None then
      i := (match quoted_end text !i with Some e -> e | None -> !i + 1)
    (* ('"', '\"': a character, not a string) *)
    else if c = '\'' && !i + 2 < n && text.[!i + 2] = '\'' then i := !i + 3
    else if c = '\'' && !i + 3 < n && text.[!i + 1] = '\\' && text.[!i + 3] = '\'' then i := !i + 4
    else if c >= 'A' && c <= 'Z' && (!i = 0 || not (is_ident text.[!i - 1])) then begin
      let j = ref !i in
      while !j < n && is_ident text.[!j] do incr j done;
      let w = String.sub text !i (!j - !i) in
      let dotted = !j < n && text.[!j] = '.' in
      (* (Fpath_.Operators: a unit, then its submodule) *)
      let inner = !i > 0 && text.[!i - 1] = '.' in
      if dotted && not inner then Hashtbl.replace h w ()
      else if dotted then ()
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

let mentions (t : t) (text : string) : unit =
  let n = String.length text in
  let i = ref 0 in
  while !i < n do
    let c = text.[!i] in
    if c >= 'A' && c <= 'Z' && (!i = 0 || not (is_ident text.[!i - 1])) then begin
      let j = ref !i in
      while !j < n && is_ident text.[!j] do incr j done;
      if !j < n && text.[!j] = '.' then Hashtbl.replace t.needed (String.sub text !i (!j - !i)) ();
      i := !j
    end
    else incr i
  done

(* the directories in common, from the top: tiny/TinyML and tiny/TinyC 1 *)
let near (a : string) (b : string) : int =
  let parts (s : string) = List.filter (fun (x : string) -> x <> "" && x <> ".") (String.split_on_char '/' s) in
  let rec common (x : string list) (y : string list) : int =
    match x, y with
    | p :: x, q :: y when p = q -> 1 + common x y
    | _ -> 0 in
  common (parts a) (parts b)

let choose (t : t) (from : string) (name : string) (exts : string list) : string option =
  match index t with
  | None -> None
  | Some idx -> (
      (* (a directory with its own Stdlib is another platform's library,
       * tiny/TinyLibCore: not the program's, whose library is given) *)
      let other_stdlib (d : string) : bool =
        match Hashtbl.find_opt idx.names d with Some names -> Hashtbl.mem names "Stdlib" | None -> false in
      match List.filter (fun (d : string) -> not (other_stdlib d))
              (List.concat_map (fun (e : string) -> found idx.homes (name ^ e)) exts) with
      | [] -> None
      | ds ->
          let supplies (d : string) : int =
            match Hashtbl.find_opt idx.names d with
            | None -> 0
            | Some names -> Hashtbl.fold (fun (u : string) () n -> if Hashtbl.mem names u then n + 1 else n) t.needed 0 in
          let score (d : string) : int * int * int =
            ((if Hashtbl.mem t.chosen d then 1 else 0), supplies d, near (Filename.dirname from) d) in
          (* (the best first; among equals, by name) *)
          let ranked =
            List.sort (fun (a : string) (b : string) -> compare (score b, a) (score a, b)) (List.sort_uniq compare ds) in
          match ranked with
          | [] -> None
          | best :: rest ->
              (match rest with
               | next :: _ when score next = score best ->
                   Logs.warn (fun m -> m "unit %s (named in %s): %s or %s, a tie; %s taken (-I or -own to choose)" name from best next best)
               | _ -> ());
              (* (-v: the candidates by their score, when there was a choice) *)
              let why (d : string) : string =
                let c, s, n = score d in
                Printf.sprintf "%s (%s%d of the names used there, %d path parts in common)" d
                  (if c = 1 then "chosen before, " else "") s n in
              if not (Hashtbl.mem t.chosen best) then
                Logs.info (fun m ->
                    match rest with
                    | [] -> m "unit %s (named in %s): %s, the one directory with its file" name from best
                    | _ -> m "unit %s (named in %s): %s" name from (String.concat ", rather than " (List.map why ranked)));
              Hashtbl.replace t.chosen best ();
              Some best)

(* the standard libraries: each directory with a Stdlib, or the one above
 * it with a units.txt (lib_core/core's is lib_core's) *)
let library (caps : < Cap.readdir; .. >) (file : string) : string option =
  let t = create caps file in
  match index t with
  | None -> None
  | Some idx ->
      let libs =
        Hashtbl.fold
          (fun (d : string) (names : (string, unit) Hashtbl.t) acc ->
            if not (Hashtbl.mem names "Stdlib") then acc
            else if CapSys.file_exists caps (Filename.concat (Filename.dirname d) "units.txt") then Filename.dirname d :: acc
            else d :: acc)
          idx.names [] in
      let depth (d : string) : int = List.length (String.split_on_char '/' d) in
      (* (the nearest, then the shallowest: the more general) *)
      let score (d : string) : int * int = (near (Filename.dirname file) d, - depth d) in
      match List.sort (fun (a : string) (b : string) -> compare (score b, a) (score a, b)) (List.sort_uniq compare libs) with
      | [] -> None
      | best :: rest ->
          Logs.info (fun m ->
              m "library: %s, no -L: the nearest standard library to %s, then the shallowest%s" best file
                (if rest = [] then "" else ", rather than " ^ String.concat ", " rest));
          Some best

(* the units the build makes: a lexer from its .mll, a parser from its .mly *)
let generated (caps : < Cap.readdir; .. >) (t : t) (dir : string) (name : string) : string option option =
  let sources =
    List.concat_map (fun ext -> [ String.uncapitalize_ascii name ^ ext; name ^ ext ]) [ ".mll"; ".mly" ] in
  match List.find_opt (fun n -> CapSys.file_exists caps (Filename.concat dir n)) sources with
  | None -> None
  | Some source ->
    (* (dune's build directory mirrors the sources: the project's
     * _build/default, then the directory's path from the root) *)
    let built =
      match index t with
      | None -> None
      | Some _ ->
          let d = FS.cleanname dir in
          let rel =
            if t.root = "." then Some d
            else if String.starts_with ~prefix:(t.root ^ "/") d then
              Some (String.sub d (String.length t.root + 1) (String.length d - String.length t.root - 1))
            else None in
          Option.map (fun r -> Filename.concat (Filename.concat t.root "_build/default") r) rel in
    match built with
    | Some b when List.exists (fun n -> CapSys.file_exists caps (Filename.concat b n))
                    [ String.uncapitalize_ascii name ^ ".ml"; name ^ ".ml" ] ->
        Logs.info (fun m -> m "unit %s: made by the build from %s, dune's in %s" name (Filename.concat dir source) b);
        Some (Some b)
    | _ -> Some None
