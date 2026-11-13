(* Int32: a subset of OCaml's module (see Stdlib.mli). Its integers of 32
 * bits are for the machine's words (TinyLibMachine.word: a datum, a
 * .word, or an illegal instruction's word). tiny-ml's ints have 31
 * bits, so here a number is made of two pieces of 16 bits, as an Int64
 * is made of four. There is no mul, div or of_string: the words are
 * made by Int64's to_int32 or by of_int, and read by pieces. The type
 * is named int32, as OCaml names it, because tiny-ml's types share one
 * name space, where t is already taken. *)

val zero : int32
val one : int32
val minus_one : int32
val max_int : int32
val min_int : int32
val of_int : int -> int32
val to_int : int32 -> int
val add : int32 -> int32 -> int32
val sub : int32 -> int32 -> int32
val neg : int32 -> int32
val logand : int32 -> int32 -> int32
val logor : int32 -> int32 -> int32
val logxor : int32 -> int32 -> int32
val lognot : int32 -> int32
val shift_left : int32 -> int -> int32
val shift_right : int32 -> int -> int32
val shift_right_logical : int32 -> int -> int32
val equal : int32 -> int32 -> bool
val compare : int32 -> int32 -> int
val to_string : int32 -> string
