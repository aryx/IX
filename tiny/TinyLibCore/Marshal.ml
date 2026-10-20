(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Marshal.mli *)

type extern_flags = No_sharing | Closures
external to_string : 'a -> extern_flags list -> string = "ml_marshal_to_string"
external from_string : string -> int -> 'a = "ml_marshal_from_string"
