(* Buffer, OCaml's subset (see Stdlib.mli): bytes that double when
 * full, from 256 at most (a program's partition is 1 MB, create's
 * size a guess) (old: a string grown by ^, quadratic) *)
type t
val create : int -> t
val add_string : t -> string -> unit
val add_char : t -> char -> unit
val contents : t -> string
val length : t -> int
val clear : t -> unit
