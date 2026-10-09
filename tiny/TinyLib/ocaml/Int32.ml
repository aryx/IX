(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. GNU Library General Public License. *)

(* $Id$ *)

(* Module [Int32]: 32-bit integers *)

type t

external logor: t -> t -> t = "int32_or"
external shift_left: t -> int -> t = "int32_shift_left"
external shift_right_logical: t -> int -> t = "int32_shift_right_unsigned"
external of_int: int -> t = "int32_of_int"
external to_int: t -> int = "int32_to_int"


external format : string -> t -> string = "int32_format"
let to_string n = format "%d" n


(* ix: OCaml's later functions, those ix's programs use *)


(* the bits of the single-precision float nearest to a float, IEEE's 32 *)
external bits_of_float : float -> t = "int32_bits_of_float"
