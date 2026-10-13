(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. GNU Library General Public License. *)

(* $Id$ *)

(* Module [Int64]: 64-bit integers *)

type t

external neg: t -> t = "int64_neg"
external add: t -> t -> t = "int64_add"
external sub: t -> t -> t = "int64_sub"
external mul: t -> t -> t = "int64_mul"
external div: t -> t -> t = "int64_div"
external rem: t -> t -> t = "int64_mod"
external logand: t -> t -> t = "int64_and"
external logor: t -> t -> t = "int64_or"
external logxor: t -> t -> t = "int64_xor"
external shift_left: t -> int -> t = "int64_shift_left"
external shift_right: t -> int -> t = "int64_shift_right"
external shift_right_logical: t -> int -> t = "int64_shift_right_unsigned"
external of_int: int -> t = "int64_of_int"
external to_int: t -> int = "int64_to_int"
external of_int32: Int32.t -> t = "int64_of_int32"
external to_int32: t -> Int32.t = "int64_to_int32"

let zero = of_int 0
let one = of_int 1
let minus_one = of_int (-1)
let succ n = add n one
let pred n = sub n one
let min_int = shift_left one 63
let lognot n = logxor n minus_one

external format : string -> t -> string = "int64_format"
let to_string n = format "%d" n

external of_string: string -> t = "int64_of_string"

(* ix: OCaml's later functions, those ix's programs use *)

let compare (a : t) (b : t) = Pervasives.compare a b
let of_string_opt s = try Some (of_string s) with Failure _ -> None

(* without a sign: the order is the signed one of the two moved by 2^63;
 * the division from the signed one of n/2 (Hacker's Delight, 9-3) *)
let unsigned_compare a b = compare (sub a min_int) (sub b min_int)

let unsigned_div n d =
  if compare d zero < 0 then (if unsigned_compare n d < 0 then zero else one)
  else
    let q = shift_left (div (shift_right_logical n 1) d) 1 in
    let r = sub n (mul q d) in
    if unsigned_compare r d >= 0 then succ q else q

(* a float's bits, IEEE's 64; a float cut to its integer part, an
 * integer as the nearest float *)
external bits_of_float : float -> t = "int64_bits_of_float"
external of_float : float -> t = "int64_of_float"
external to_float : t -> float = "int64_to_float"
