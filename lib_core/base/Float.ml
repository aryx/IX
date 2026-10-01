(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 2018 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

external neg : float -> float = "%negfloat"
external add : float -> float -> float = "%addfloat"
external sub : float -> float -> float = "%subfloat"
external mul : float -> float -> float = "%mulfloat"
external div : float -> float -> float = "%divfloat"
(* external rem : float -> float -> float = "caml_fmod_float" "fmod" 
 (*[@@unboxed] [@@noalloc]*) *)
external abs : float -> float = "%absfloat"
let infinity = Pervasives.infinity
let neg_infinity = Pervasives.neg_infinity
let nan = Pervasives.nan
let max_float = Pervasives.max_float
let min_float = Pervasives.min_float
let epsilon_float = Pervasives.epsilon_float

external of_int : int -> float = "%floatofint"
external to_int : float -> int = "%intoffloat"
external of_string : string -> float = "float_of_string"
(*let of_string_opt = Pervasives.float_of_string_opt *)
let to_string = Pervasives.string_of_float

(*
type fpclass = Pervasives.fpclass =
    FP_normal
  | FP_subnormal
  | FP_zero
  | FP_infinite
  | FP_nan
external classify_float : (float (*[@unboxed]*)) -> fpclass =
  "caml_classify_float" "caml_classify_float_unboxed" (*[@@noalloc]*)
 *)

external pow : float -> float -> float = "power_float" "pow"
  (*[@@unboxed] [@@noalloc]*)
external sqrt : float -> float = "sqrt_float" "sqrt"
  (*[@@unboxed] [@@noalloc]*)
external exp : float -> float = "exp_float" "exp" (*[@@unboxed] [@@noalloc]*)
external log : float -> float = "log_float" "log" (*[@@unboxed] [@@noalloc]*)
external log10 : float -> float = "log10_float" "log10"
  (*[@@unboxed] [@@noalloc]*)
(*external expm1 : float -> float = "expm1_float" "caml_expm1"
 (*[@@unboxed] [@@noalloc]*) *)
(*external log1p : float -> float = "log1p_float" "caml_log1p"
  (*[@@unboxed] [@@noalloc]*)
 *)
external cos : float -> float = "cos_float" "cos" (*[@@unboxed] [@@noalloc]*)
external sin : float -> float = "sin_float" "sin" (*[@@unboxed] [@@noalloc]*)
external tan : float -> float = "tan_float" "tan" (*[@@unboxed] [@@noalloc]*)
external acos : float -> float = "acos_float" "acos"
  (*[@@unboxed] [@@noalloc]*)
external asin : float -> float = "asin_float" "asin"
  (*[@@unboxed] [@@noalloc]*)
external atan : float -> float = "atan_float" "atan"
  (*[@@unboxed] [@@noalloc]*)
external atan2 : float -> float -> float = "atan2_float" "atan2"
  (*[@@unboxed] [@@noalloc]*)
(*external hypot : float -> float -> float
               = "hypot_float" "caml_hypot" (*[@@unboxed] [@@noalloc]*) *)
external cosh : float -> float = "cosh_float" "cosh"
  (*[@@unboxed] [@@noalloc]*)
external sinh : float -> float = "sinh_float" "sinh"
  (*[@@unboxed] [@@noalloc]*)
external tanh : float -> float = "tanh_float" "tanh"
  (*[@@unboxed] [@@noalloc]*)
external ceil : float -> float = "ceil_float" "ceil"
  (*[@@unboxed] [@@noalloc]*)
external floor : float -> float = "floor_float" "floor"
(*[@@unboxed] [@@noalloc]*)
(*external copysign : float -> float -> float
                  = "caml_copysign_float" "caml_copysign"
 (*[@@unboxed] [@@noalloc]*) *)
let frexp = Pervasives.frexp
(* external ldexp : (float (*[@unboxed]*)) -> (int (*[@untagged]*)) -> (float (*[@unboxed]*)) =
  "caml_ldexp_float" "caml_ldexp_float_unboxed" (*[@@noalloc]*)
 *)

(*external modf : float -> float * float = "caml_modf_float" *)
type t = float
(*
external compare : float -> float -> int = "%compare"
 *)
let compare : t -> t -> int = compare
let equal x y = compare x y = 0

(* ix: OCaml's later functions, those ix's programs use *)

let is_nan (x : float) = x <> x

(* to an integer, toward zero; to the nearest, a half away from zero
 * (x -. t is exact) *)
let trunc x = if x >= 0.0 then floor x else ceil x

let round x =
  let t = trunc x in
  if x -. t >= 0.5 then t +. 1.0 else if t -. x >= 0.5 then t -. 1.0 else t

(* nan if one is; -0.0 less than 0.0, which < doesn't say *)
let sign_bit x = Int64.compare (Int64.bits_of_float x) 0L < 0

let min (x : float) (y : float) =
  if y > x || (not (sign_bit y) && sign_bit x) then (if is_nan y then y else x)
  else if is_nan x then x else y

let max (x : float) (y : float) =
  if y > x || (not (sign_bit y) && sign_bit x) then (if is_nan x then x else y)
  else if is_nan y then y else x

(* x * y + z rounded once, without the instruction (Boldo and
 * Melquiond, "Emulation of a FMA and correctly rounded sums: proved
 * algorithms using rounding to odd"): the product exact as two floats
 * (Dekker's, by Veltkamp's splitting), the three summed, the low part
 * rounded to odd (its last bit set when inexact) so that the last sum
 * rounds as the exact value does. Not for the ends of the range: the
 * splitting overflows above 2^996, and a product's low part below the
 * smallest float is lost. *)
let fma x y z =
  let two_sum a b = let s = a +. b in let bb = s -. a in s, (a -. (s -. bb)) +. (b -. bb) in
  let split a = let c = 134217729.0 *. a in let h = c -. (c -. a) in h, a -. h in
  let p = x *. y in
  let finite a = not (is_nan (a -. a)) in
  (* an infinite z is the result, whatever the finite product (which may overflow) *)
  if finite x && finite y && not (finite z) then z
  else if not (finite p) || p = 0.0 then p +. z
  else begin
    let xh, xl = split x and yh, yl = split y in
    let pl = ((xh *. yh -. p) +. xh *. yl +. xl *. yh) +. xl *. yl in
    let uh, ul = two_sum z pl in
    let th, tl = two_sum p uh in
    let s, e = two_sum tl ul in
    let bits = Int64.bits_of_float s in
    let odd =
      if e = 0.0 || Int64.logand bits 1L = 1L then s
      else Int64.float_of_bits (if (e > 0.0) = (s > 0.0) then Int64.succ bits else Int64.pred bits)
    in
    th +. odd
  end
