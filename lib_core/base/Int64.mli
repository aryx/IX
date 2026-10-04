(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License.         *)
(*                                                                     *)
(***********************************************************************)

(* $Id$ *)

(* Module [Int64]: 64-bit integers *)

(* This module provides the type [Int64.t] of signed 64-bit integers and its
   associated arithmetic operations.  Unlike the built-in [int] type,
   the type [Int64.t] is guaranteed to be exactly 64-bit wide on all
   platforms.  All arithmetic operations over [Int64.t] are taken
   modulo $2^{64}$.  

   The type [Int64.t] is available on all 64-bit platforms, as well as
   on all 32-bit platforms for which the C compiler supports 64-bit
   arithmetic.  On 32-bit platforms without support for 64-bit arithmetic,
   all functions in this module raise an [Invalid_argument] exception.
*)

type t
      (* The type of 64-bit integers. *)

val zero: t
val one: t
val minus_one: t
      (* The 64-bit integers 0, 1, -1. *)

external neg: t -> t = "int64_neg"
      (* Unary negation. *)
external add: t -> t -> t = "int64_add"
      (* Addition. *)
external sub: t -> t -> t = "int64_sub"
      (* Subtraction. *)
external mul: t -> t -> t = "int64_mul"
      (* Multiplication. *)
external div: t -> t -> t = "int64_div"
      (* Integer division. Raise [Division_by_zero] if the second argument
         is zero. *)
external rem: t -> t -> t = "int64_mod"
      (* Integer remainder. *)
val succ: t -> t
      (* Successor. *)
val pred: t -> t
      (* Predecessor. *)
val abs: t -> t
      (* Return the absolute value of its argument. *)
val max_int: t
      (* The greatest representable 64-bit integer, $2^{63} - 1$. *)
val min_int: t
      (* The smallest representable 64-bit integer, $-2^{63}$. *)

external logand: t -> t -> t = "int64_and"
      (* Bitwise logical and. *)
external logor: t -> t -> t = "int64_or"
      (* Bitwise logical or. *)
external logxor: t -> t -> t = "int64_xor"
      (* Bitwise logical exclusive or. *)
val lognot: t -> t
      (* Bitwise logical negation *)
external shift_left: t -> int -> t = "int64_shift_left"
      (* [Int64.shift_left x y] shifts [x] to the left by [y] bits. *)
external shift_right: t -> int -> t = "int64_shift_right"
      (* [Int64.shift_right x y] shifts [x] to the right by [y] bits. *)
external shift_right_logical: t -> int -> t = "int64_shift_right_unsigned"
      (* [Int64.shift_right_logical x y] shifts [x] to the right by [y]
         bits. *)

external of_int: int -> t = "int64_of_int"
      (* Convert the given integer (type [int]) to a 64-bit integer (type
         [Int64.t]). *)
external to_int: t -> int = "int64_to_int"
      (* Convert the given 64-bit integer (type [Int64.t]) to an integer
         (type [int]). *)

external of_int32: Int32.t -> t = "int64_of_int32"
      (* Convert the given 32-bit integer (type [Int32.t]) to a 64-bit
         integer (type [Int64.t]). *)
external to_int32: t -> Int32.t = "int64_to_int32"
      (* Convert the given 64-bit integer (type [Int64.t]) to a 32-bit
         integer (type [Int32.t]). *)

external of_string: string -> t = "int64_of_string"
      (* Convert the given string to a 64-bit integer. Raise [Failure
         "int_of_string"] if the given string is not a valid representation
         of an integer. *)
val to_string: t -> string
      (* Return the string representation of its argument, in decimal. *)
external format : string -> t -> string = "int64_format"
      (* [Int64.format fmt n] return the string representation of the 64-bit
         integer [n] in the format specified by [fmt]. *)


(* ix: OCaml's later functions, those ix's programs use *)

val compare : t -> t -> int
val of_string_opt : string -> t option

(* the two as integers without a sign, of 0 to 2^64 - 1 *)
val unsigned_compare : t -> t -> int
val unsigned_div : t -> t -> t
val unsigned_rem : t -> t -> t

(* a float's bits, IEEE's 64; a float cut to its integer part, an
 * integer as the nearest float *)
external bits_of_float : float -> t = "int64_bits_of_float"
external float_of_bits : t -> float = "int64_float_of_bits"
external of_float : float -> t = "int64_of_float"
external to_float : t -> float = "int64_to_float"
