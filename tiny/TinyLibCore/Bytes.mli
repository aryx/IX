(* Bytes, OCaml's subset (see Stdlib.mli): a string that can be changed
 * (old: none, and a string of samples a list, a cons a byte: 2,750
 * instructions a byte, plan_tiny_audio.md) *)
val make : int -> char -> bytes
val length : bytes -> int
val get : bytes -> int -> char
val set : bytes -> int -> char -> unit
val to_string : bytes -> string
val of_string : string -> bytes
val blit_string : string -> int -> bytes -> int -> int -> unit
val blit : bytes -> int -> bytes -> int -> int -> unit
val sub_string : bytes -> int -> int -> string
