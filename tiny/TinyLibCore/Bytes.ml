(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Bytes.mli *)

external make : int -> char -> bytes = "ml_string_make"
external length : bytes -> int = "ml_string_length"
external get : bytes -> int -> char = "ml_string_get"
external set : bytes -> int -> char -> unit = "ml_bytes_set"
external to_string : bytes -> string = "ml_bytes_to_string"
(* (a copy, either way: the runtime's one function) *)
external of_string : string -> bytes = "ml_bytes_to_string"
external blit_string : string -> int -> bytes -> int -> int -> unit
  = "ml_bytes_blit_string"

(* (bytes and a string are the same block: string's functions; blit
 * copies forward, so not within one bytes to a later place) *)
external blit : bytes -> int -> bytes -> int -> int -> unit = "ml_bytes_blit_string"
external unsafe_sub : bytes -> int -> int -> string = "ml_string_sub"
let sub_string b ofs len =
  if ofs < 0 || len < 0 || ofs > length b - len
  then invalid_arg "Bytes.sub_string"
  else unsafe_sub b ofs len
