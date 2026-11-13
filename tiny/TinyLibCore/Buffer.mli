(* Buffer: a subset of OCaml's module (see Stdlib.mli). A buffer is
 * bytes that double in size when full. They start at 256 bytes at most,
 * because a program's partition is 1 MB, and the size given to create
 * is only a guess. *)
type t
val create : int -> t
val add_string : t -> string -> unit
val add_char : t -> char -> unit
val contents : t -> string
val length : t -> int
val clear : t -> unit
