(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tiny_manifest.mli *)

type taken = Manifest.taken = Command_line | Archive_member of string
type ppath = Manifest.ppath = Ppath of string
type linked = Manifest.linked = {
  l_object : string;
  l_source : ppath option;
  l_flags : string list;
  l_taken : taken;
}
type manifest = Manifest.manifest = { m_program : string; m_units : linked list }

let of_string = Manifest.of_string
let to_string = Manifest.to_string

(* (the first directory up from d with a units.txt or a Stdlib.mli) *)
let rec standard_library (caps : < Cap.open_in; .. >) (d : string) :
    string option =
  let has (f : string) = FS.read_opt caps (Fpath.v (Filename.concat d f)) <> None in
  let up = Filename.dirname d in
  if has "units.txt" then Some d
  (* (lib_core/core's Stdlib.mli is lib_core's, whose units.txt is above;
   * TinyLibCore's, with none, its own) *)
  else if has "Stdlib.mli" then
    (if FS.read_opt caps (Fpath.v (Filename.concat up "units.txt")) <> None then Some up else Some d)
  else
    let up = Filename.dirname d in
    if up = d || d = "." || d = "/" then None else standard_library caps up

type program = {
  name : string;
  own : string list;
  components : string list;
  own_dirs : string list;
  library : string option;
  units : (string * string) list;
  c : (string * (string list * string list)) list;
}

let of_manifest (caps : < Cap.open_in; Cap.readdir; .. >) (m : manifest)
    (others : manifest list) (root : string) : program =
  (* (relative to here when under it: a build outside the tree, make
   * test's, names the tree's files as a build inside it does) *)
  let here = FS.getcwd caps () ^ "/" in
  let at (p : string) : string =
    let p = FS.cleanname (if Filename.is_relative p then Filename.concat root p else p) in
    let n = String.length here in
    if String.length p > n && String.sub p 0 n = here then String.sub p n (String.length p - n)
    else p in
  (* (the ML units: a C or assembly file is the runtime's) *)
  let ml =
    List.filter_map (fun (l : linked) ->
        match l.l_source with
        | Some (Ppath s) when Filename.check_suffix s ".ml" -> Some (at s, l.l_taken)
        | _ -> None)
      m.m_units in
  let unit_of (f : string) : string =
    String.capitalize_ascii (Filename.remove_extension (Filename.basename f)) in
  let members =
    List.filter_map (fun (f, t) ->
        match t with Archive_member _ -> Some f | Command_line -> None)
      ml in
  (* (from an archive's member, else from a unit given to the linker: a
   * kernel links lib_core's objects one by one, mkkernel's STDOBJS) *)
  let library =
    match List.find_map (fun f -> standard_library caps (Filename.dirname f)) members with
    | Some l -> Some l
    | None ->
        List.find_map (fun (f, _) -> standard_library caps (Filename.dirname f)) ml in
  let under (d : string) (f : string) : bool =
    let d = d ^ "/" in
    String.length f > String.length d && String.sub f 0 (String.length d) = d in
  (* (the files given to the linker, but the standard library's: mkprog
   * gives lib_core's std_exit.7 after the program's units, from one of
   * the directories of its archive's members; lib_core's own tests are
   * programs) *)
  let library_dirs =
    (* (its own directories: units.txt's, and commons/, as Ml_front's
     * search; TinyLibCore's, one, its Stdlib.mli's) *)
    match library with
    | None -> []
    | Some l -> (
        match FS.read_opt caps (Fpath.v (Filename.concat l "units.txt")) with
        | None -> [ l ]
        | Some text ->
            Filename.concat l "commons"
            :: List.filter_map (fun (line : string) ->
                   let line = String.trim line in
                   if line = "" || line.[0] = '#' then None
                   else Some (Filename.concat l (Filename.dirname line)))
                 (String.split_on_char '\n' text)) in
  let given =
    List.filter_map (fun (f, t) ->
        if t = Command_line && not (List.mem (Filename.dirname f) library_dirs)
        then Some f else None)
      ml in
  let part =
    match given with
    | f :: _ -> Module_finder.part_dir caps f
    | [] -> None in
  let own_member (f : string) : bool =
    (match part with Some p -> under p f | None -> false)
    && not (match library with Some l -> under l f | None -> false) in
  (* (the files another program of the build links: a library's) *)
  let shared = Hashtbl.create 64 in
  List.iter (fun (o : manifest) ->
      List.iter (fun (l : linked) ->
          Option.iter (fun (Ppath s) -> Hashtbl.replace shared (at s) ()) l.l_source)
        o.m_units)
    others;
  { name = m.m_program;
    own = given;
    components = List.filter (fun f -> not (Hashtbl.mem shared f)) given;
    own_dirs =
      List.sort_uniq compare
        (List.filter_map
           (fun f -> if own_member f then Some (Filename.dirname f) else None)
           members);
    library;
    units = List.map (fun (f, _) -> (unit_of f, f)) ml;
    c =
      List.filter_map (fun (l : linked) ->
          match l.l_source with
          | Some (Ppath s) when Filename.check_suffix s ".c" ->
              (* (its -D's, and its -I's from the project's top) *)
              let flag (k : string) (x : string) : string option =
                if String.length x > 2 && String.sub x 0 2 = k then Some (String.sub x 2 (String.length x - 2))
                else None in
              let defs = List.filter_map (flag "-D") l.l_flags in
              let incs = List.map at (List.filter_map (flag "-I") l.l_flags) in
              Some (at s, (defs, incs))
          | _ -> None)
        m.m_units }

let root (caps : < Cap.readdir; .. >) (file : string) (project : string option) : string =
  match project with
  | Some d -> d
  | None ->
      (* (the first directory up with a dune-project, as git finds its
       * root; a build outside every project's, here's) *)
      let rec top (d : string) : string option =
        if CapSys.file_exists caps (Filename.concat d "dune-project") then Some d
        else if Filename.dirname d = d then None
        else top (Filename.dirname d) in
      let cwd = FS.getcwd caps () in
      let dir = Filename.dirname file in
      let abs = if Filename.is_relative dir then Filename.concat cwd dir else dir in
      (match top (FS.cleanname abs) with Some d -> d | None -> cwd)

let program (caps : < Cap.open_in; Cap.readdir; .. >) (file : string)
    (project : string option) : program =
  let m = of_string (FS.read caps (Fpath.v file)) in
  (* (the build's other programs: the manifests beside it, tiny-ld's
   * links writing each beside its program) *)
  let dir = Filename.dirname file in
  let others =
    Array.to_list (CapSys.readdir caps dir)
    |> List.filter (fun n ->
           Filename.check_suffix n ".manifest" && n <> Filename.basename file)
    |> List.filter_map (fun n ->
           match of_string (FS.read caps (Fpath.v (Filename.concat dir n))) with
           | o -> Some o
           | exception Failure _ -> None) in
  of_manifest caps m others (root caps file project)

let linking (m : manifest) (root : string) (file : string) : bool =
  let file = FS.cleanname file in
  List.exists (fun (l : linked) ->
      match l.l_source with
      | Some (Ppath s) ->
          FS.cleanname (if Filename.is_relative s then Filename.concat root s else s) = file
      | None -> false)
    m.m_units
