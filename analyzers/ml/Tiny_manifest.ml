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

type program = {
  name : string;
  own : string list;
  library : string option;
  units : (string * string) list;
}

let program (caps : < Cap.open_in; .. >) (file : string)
    (sources : string option) : program =
  let m = of_string (FS.read caps (Fpath.v file)) in
  let root = match sources with Some d -> d | None -> Filename.dirname file in
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
  let archive_dir ((f, t) : string * taken) : string option =
    match t with
    | Archive_member _ -> Some (Filename.dirname f)
    | Command_line -> None in
  { name = m.m_program;
    own = List.filter_map (fun (f, t) -> if t = Command_line then Some f else None) ml;
    library = List.find_map archive_dir ml;
    units = List.map (fun (f, _) -> (unit_of f, f)) ml }
