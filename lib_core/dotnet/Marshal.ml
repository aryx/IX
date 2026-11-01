(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* lib_core's Marshal on .NET, in its place (mini-ml -dotnet -L takes
 * dotnet/'s unit of a name over lib_core's): a value's bytes are
 * OCaml's blocks' (core/Marshal.ml reads them by Obj), which a .NET
 * object has not; so each function fails, by its name, where a
 * program calls it. Its .mli is lib_core's, core/Marshal.mli. *)

type extern_flags = No_sharing | Closures

let no (f : string) : 'a = failwith ("Marshal." ^ f ^ ": no OCaml blocks on .NET")

let to_channel (_ : out_channel) (_ : 'a) (_ : extern_flags list) : unit = no "to_channel"
let to_string (_ : 'a) (_ : extern_flags list) : string = no "to_string"
let to_buffer (_ : bytes) (_ : int) (_ : int) (_ : 'a) (_ : extern_flags list) : int = no "to_buffer"
let from_channel (_ : in_channel) : 'a = no "from_channel"
let from_string (_ : string) (_ : int) : 'a = no "from_string"
let header_size = 20
let data_size (_ : bytes) (_ : int) : int = no "data_size"
let total_size (_ : bytes) (_ : int) : int = no "total_size"
let to_bytes (_ : 'a) (_ : extern_flags list) : bytes = no "to_bytes"
let from_bytes (_ : bytes) (_ : int) : 'a = no "from_bytes"
