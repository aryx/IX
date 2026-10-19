(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Bytes.mli *)

external make : int -> char -> bytes = "ml_string_make"
external length : bytes -> int = "ml_string_length"
external get : bytes -> int -> char = "ml_string_get"
external set : bytes -> int -> char -> unit = "ml_bytes_set"
external to_string : bytes -> string = "ml_bytes_to_string"
external blit_string : string -> int -> bytes -> int -> int -> unit = "ml_bytes_blit_string"
