(* TinyLib: lib_core/base/Int64, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. GNU Library General Public License. *)

(* Module [Int64]: signed 64-bit integers, exactly 64 bits wide on all
   platforms; the operations are modulo 2^64. *)

type t

val zero: t
val one: t
val minus_one: t

external neg: t -> t = "int64_neg"
external add: t -> t -> t = "int64_add"
external sub: t -> t -> t = "int64_sub"
external mul: t -> t -> t = "int64_mul"
external div: t -> t -> t = "int64_div"
      (* Raise [Division_by_zero] if the second argument is zero. *)
external rem: t -> t -> t = "int64_mod"
val succ: t -> t
val pred: t -> t
val min_int: t
      (* -2^63. *)

external logand: t -> t -> t = "int64_and"
external logor: t -> t -> t = "int64_or"
external logxor: t -> t -> t = "int64_xor"
val lognot: t -> t
external shift_left: t -> int -> t = "int64_shift_left"
external shift_right: t -> int -> t = "int64_shift_right"
external shift_right_logical: t -> int -> t = "int64_shift_right_unsigned"

external of_int: int -> t = "int64_of_int"
external to_int: t -> int = "int64_to_int"

external of_int32: Int32.t -> t = "int64_of_int32"
external to_int32: t -> Int32.t = "int64_to_int32"

external of_string: string -> t = "int64_of_string"
      (* Raise [Failure "int_of_string"] if not an integer. *)
val to_string: t -> string
      (* In decimal. *)
external format : string -> t -> string = "int64_format"
      (* [format fmt n]: [n] by the format [fmt]. *)


(* ix: OCaml's later functions, those ix's programs use *)

val compare : t -> t -> int
val of_string_opt : string -> t option

(* the two as integers without a sign, of 0 to 2^64 - 1 *)
val unsigned_compare : t -> t -> int
val unsigned_div : t -> t -> t

(* a float's bits, IEEE's 64; a float cut to its integer part, an
 * integer as the nearest float *)
external bits_of_float : float -> t = "int64_bits_of_float"
external float_of_bits : t -> float = "int64_float_of_bits"
external of_float : float -> t = "int64_of_float"
external to_float : t -> float = "int64_to_float"
