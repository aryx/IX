(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Array.mli *)

external make : int -> 'a -> 'a array = "ml_array_make"
external length : 'a array -> int = "ml_array_length"
external get : 'a array -> int -> 'a = "ml_array_get"
external set : 'a array -> int -> 'a -> unit = "ml_array_set"
