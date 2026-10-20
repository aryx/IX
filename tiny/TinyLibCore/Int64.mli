(* Int64, OCaml's subset (see Stdlib.mli): integers of 64 bits, for
 * tiny-c's constants, which are C's of 32 bits and its own long
 * temporaries (OCaml's int64; tiny-ml's ints have 31 bits, so here a
 * number is four pieces of 16). The type is named int64, as OCaml
 * names it: tiny-ml's types are one name space, where t is taken. *)

val zero : int64
val one : int64
val minus_one : int64
val max_int : int64
val min_int : int64
val of_int : int -> int64
val to_int : int64 -> int
val add : int64 -> int64 -> int64
val sub : int64 -> int64 -> int64
val mul : int64 -> int64 -> int64
val div : int64 -> int64 -> int64
val rem : int64 -> int64 -> int64
val neg : int64 -> int64
val succ : int64 -> int64
val pred : int64 -> int64
val abs : int64 -> int64
val logand : int64 -> int64 -> int64
val logor : int64 -> int64 -> int64
val logxor : int64 -> int64 -> int64
val lognot : int64 -> int64
val shift_left : int64 -> int -> int64
val shift_right : int64 -> int -> int64
val shift_right_logical : int64 -> int -> int64
val equal : int64 -> int64 -> bool
val compare : int64 -> int64 -> int
val to_string : int64 -> string
val of_string : string -> int64
