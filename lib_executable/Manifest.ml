(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Manifest.mli *)

type taken = Command_line | Archive_member of string
type ppath = Ppath of string
type linked = { l_object : string; l_source : ppath option; l_flags : string list; l_taken : taken }
type manifest = { m_program : string; m_units : linked list }

(* (TinyLibExecutable's) *)
let magic = "tiny-manifest 3\n"

let to_string (m : manifest) : string =
  magic ^ Marshal_.to_string m [ Marshal.No_sharing ]

let of_string (s : string) : manifest =
  let n = String.length magic in
  if String.length s < n || String.sub s 0 n <> magic then
    failwith "not a manifest (tiny-manifest 3): link again";
  Marshal.from_string s n
