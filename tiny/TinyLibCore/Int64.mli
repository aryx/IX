(* Int64: a subset of OCaml's module (see Stdlib.mli). Its integers of
 * 64 bits are for tiny-cc's constants, which are C's constants of 32
 * bits and tiny-cc's own long temporaries, kept in OCaml's int64.
 * tiny-ml's ints have 31 bits, so here a number is made of four pieces
 * of 16 bits. The type is named int64, as OCaml names it, because
 * tiny-ml's types share one name space, where t is already taken. *)

val zero : int64
val one : int64
val minus_one : int64
val max_int : int64
val min_int : int64
val of_int : int -> int64
val to_int : int64 -> int
val of_int32 : int32 -> int64
val to_int32 : int64 -> int32
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
val of_string_opt : string -> int64 option
