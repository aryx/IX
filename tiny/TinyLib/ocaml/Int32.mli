(* TinyLib: lib_core/base/Int32, the part the tiny programs call (tiny/TinyLib/README.md) *)
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

(* Module [Int32]: 32-bit integers *)

(* This module provides the type [Int32.t] of signed 32-bit integers and its
   associated arithmetic operations.  Unlike the built-in [int] type,
   the type [Int32.t] is guaranteed to be exactly 32-bit wide on all
   platforms.  All arithmetic operations over [Int32.t] are taken
   modulo $2^{32}$. *)

type t
      (* The type of 32-bit integers. *)


external logor: t -> t -> t = "int32_or"
      (* Bitwise logical or. *)
external shift_left: t -> int -> t = "int32_shift_left"
      (* [Int32.shift_left x y] shifts [x] to the left by [y] bits. *)
external shift_right_logical: t -> int -> t = "int32_shift_right_unsigned"
      (* [Int32.shift_right_logical x y] shifts [x] to the right by [y]
         bits. *)

external of_int: int -> t = "int32_of_int"
      (* Convert the given integer (type [int]) to a 32-bit integer (type
         [Int32.t]). *)
external to_int: t -> int = "int32_to_int"
      (* Convert the given 32-bit integer (type [Int32.t]) to an integer
         (type [int]). *)

val to_string: t -> string
      (* Return the string representation of its argument, in signed
         decimal. *)
external format : string -> t -> string = "int32_format"
      (* [Int32.format fmt n] return the string representation of the 32-bit
         integer [n] in the format specified by [fmt]. *)

(* ix: OCaml's later functions, those ix's programs use *)


(* the bits of the single-precision float nearest to a float, IEEE's 32 *)
external bits_of_float : float -> t = "int32_bits_of_float"
