(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Caller_finder.mli *)

let unit_of (file : string) : string = String.capitalize_ascii (Filename.remove_extension (Filename.basename file))

let names = Unit_finder.names

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
