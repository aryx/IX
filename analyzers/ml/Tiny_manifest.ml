(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tiny_manifest.mli *)

type taken = Command_line | Archive_member of string
type linked = {
  l_object : string;
  l_source : string option;
  l_taken : taken;
}
type manifest = { m_program : string; m_units : linked list }

(* (TinyLibExecutable's) *)
let magic = "tiny-manifest 1\n"

let of_string (s : string) : manifest =
  let n = String.length magic in
  if String.length s < n || String.sub s 0 n <> magic then
    failwith "not a manifest of this tiny-ld's (tiny-manifest 1): link again";
  Marshal.from_string s n

let to_string (m : manifest) : string =
  magic ^ Marshal.to_string m [ Marshal.No_sharing ]

(* (the first directory up from d with a units.txt or a Stdlib.mli) *)
let rec standard_library (caps : < Cap.open_in; .. >) (d : string) :
    string option =
  let has (f : string) = FS.read_opt caps (Fpath.v (Filename.concat d f)) <> None in
  if has "units.txt" || has "Stdlib.mli" then Some d
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
}

let of_manifest (caps : < Cap.open_in; Cap.readdir; .. >) (m : manifest)
    (others : manifest list) (root : string) : program =
  let at (p : string) : string =
    FS.cleanname (if Filename.is_relative p then Filename.concat root p else p) in
  (* (the ML units: a C or assembly file is the runtime's) *)
  let ml =
    List.filter_map (fun (l : linked) ->
        match l.l_source with
        | Some s when Filename.check_suffix s ".ml" -> Some (at s, l.l_taken)
        | _ -> None)
      m.m_units in
  let unit_of (f : string) : string =
    String.capitalize_ascii (Filename.remove_extension (Filename.basename f)) in
  let given =
    List.filter_map (fun (f, t) -> if t = Command_line then Some f else None) ml in
  let members =
    List.filter_map (fun (f, t) ->
        match t with Archive_member _ -> Some f | Command_line -> None)
      ml in
  let library =
    List.find_map (fun f -> standard_library caps (Filename.dirname f)) members in
  let under (d : string) (f : string) : bool =
    let d = d ^ "/" in
    String.length f > String.length d && String.sub f 0 (String.length d) = d in
  let part =
    match given with
    | f :: _ -> Unit_finder.part_dir caps f
    | [] -> None in
  let own_member (f : string) : bool =
    (match part with Some p -> under p f | None -> false)
    && not (match library with Some l -> under l f | None -> false) in
  (* (the files another program of the build links: a library's) *)
  let shared = Hashtbl.create 64 in
  List.iter (fun (o : manifest) ->
      List.iter (fun (l : linked) ->
          Option.iter (fun s -> Hashtbl.replace shared (at s) ()) l.l_source)
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
    units = List.map (fun (f, _) -> (unit_of f, f)) ml }

let program (caps : < Cap.open_in; Cap.readdir; .. >) (file : string)
    (sources : string option) : program =
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
  of_manifest caps m others
    (match sources with Some d -> d | None -> Filename.dirname file)
