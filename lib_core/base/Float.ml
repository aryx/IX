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
let to_string = Pervasives.string_of_float

external pow : float -> float -> float = "power_float" "pow"
  (*[@@unboxed] [@@noalloc]*)
external sqrt : float -> float = "sqrt_float" "sqrt"
  (*[@@unboxed] [@@noalloc]*)
external exp : float -> float = "exp_float" "exp" (*[@@unboxed] [@@noalloc]*)
external log : float -> float = "log_float" "log" (*[@@unboxed] [@@noalloc]*)
external cos : float -> float = "cos_float" "cos" (*[@@unboxed] [@@noalloc]*)
external sin : float -> float = "sin_float" "sin" (*[@@unboxed] [@@noalloc]*)
external tan : float -> float = "tan_float" "tan" (*[@@unboxed] [@@noalloc]*)
external atan : float -> float = "atan_float" "atan"
  (*[@@unboxed] [@@noalloc]*)
external atan2 : float -> float -> float = "atan2_float" "atan2"
  (*[@@unboxed] [@@noalloc]*)
external ceil : float -> float = "ceil_float" "ceil"
  (*[@@unboxed] [@@noalloc]*)
external floor : float -> float = "floor_float" "floor"
  (*[@@unboxed] [@@noalloc]*)
let frexp = Pervasives.frexp
type t = float
let compare : t -> t -> int = compare
let equal x y = compare x y = 0

(* ix: OCaml's later functions, those ix's programs use *)

let is_nan (x : float) = x <> x
let is_finite (x : float) = x -. x = 0.

let pi = 3.14159265358979312

(* (not C's hypot: x *. x overflows where the length itself would not) *)
let hypot (x : float) (y : float) = sqrt ((x *. x) +. (y *. y))

let rem = Pervasives.mod_float

(* to an integer, toward zero; to the nearest, a half away from zero
 * (x -. t is exact) *)
let trunc x = if x >= 0.0 then floor x else ceil x

let round x =
  let t = trunc x in
  if x -. t >= 0.5 then t +. 1.0 else if t -. x >= 0.5 then t -. 1.0 else t

(* (an infinity is its own trunc: x -. x is 0 for a finite x only) *)
let is_integer x = x = trunc x && x -. x = 0.0

(* nan if one is; -0.0 less than 0.0, which < doesn't say *)
let sign_bit x = Int64.compare (Int64.bits_of_float x) 0L < 0

(* OPTIMIZATION: the signs (an Int64 each, a block in mini-ml, and
 * Int64.compare's call) looked at only where they choose, x and y equal
 * (0.0 and -0.0) or both nan; OCaml's answers in every case
 * (tests/runtime/float_min_max.ml, the bits). A quarter of
 * tests/bench/floats.ml's instructions, Render.fill's rows.
 * old:
 *   let min x y =
 *     if y > x || (not (sign_bit y) && sign_bit x) then (if is_nan y then y else x)
 *     else if is_nan x then x else y
 *   let max x y =
 *     if y > x || (not (sign_bit y) && sign_bit x) then (if is_nan x then x else y)
 *     else if is_nan y then y else x *)
let min (x : float) (y : float) =
  if y > x then x
  else if x > y then y
  else if is_nan x then (if is_nan y && (not (sign_bit y)) && sign_bit x then y else x)
  else if is_nan y then y
  else if sign_bit x then x
  else y

let max (x : float) (y : float) =
  if y > x then y
  else if x > y then x
  else if is_nan x then (if is_nan y && not ((not (sign_bit y)) && sign_bit x) then y else x)
  else if is_nan y then y
  else if sign_bit x then y
  else x

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

module Array = struct
  type t
  external length : t -> int = "%floatarray_length"
  external get : t -> int -> float = "%floatarray_safe_get"
  external set : t -> int -> float -> unit = "%floatarray_safe_set"
  external unsafe_get : t -> int -> float = "%floatarray_unsafe_get"
  external unsafe_set : t -> int -> float -> unit = "%floatarray_unsafe_set"
  external create : int -> t = "caml_floatarray_create"

  let fill (a : t) (ofs : int) (n : int) (x : float) : unit =
    if ofs < 0 || n < 0 || ofs > length a - n then invalid_arg "Float.Array.fill";
    for i = ofs to ofs + n - 1 do unsafe_set a i x done

  let make (n : int) (x : float) : t =
    let a = create n in
    fill a 0 n x;
    a

  let init (n : int) (f : int -> float) : t =
    let a = create n in
    for i = 0 to n - 1 do unsafe_set a i (f i) done;
    a

  (* the overlapping part copied before it is overwritten *)
  let blit (src : t) (sofs : int) (dst : t) (dofs : int) (n : int) : unit =
    if n < 0 || sofs < 0 || sofs > length src - n || dofs < 0 || dofs > length dst - n
    then invalid_arg "Float.Array.blit";
    if dofs <= sofs then for i = 0 to n - 1 do unsafe_set dst (dofs + i) (unsafe_get src (sofs + i)) done
    else for i = n - 1 downto 0 do unsafe_set dst (dofs + i) (unsafe_get src (sofs + i)) done

  let copy (a : t) : t =
    let b = create (length a) in
    blit a 0 b 0 (length a);
    b

  let to_list (a : t) : float list =
    let l = ref [] in
    for i = length a - 1 downto 0 do l := unsafe_get a i :: !l done;
    !l

  let of_list (l : float list) : t =
    let a = create (List.length l) in
    List.iteri (fun (i : int) (x : float) -> unsafe_set a i x) l;
    a

  let iter (f : float -> unit) (a : t) : unit =
    for i = 0 to length a - 1 do f (unsafe_get a i) done

  let fold_left (f : 'a -> float -> 'a) (init : 'a) (a : t) : 'a =
    let acc = ref init in
    for i = 0 to length a - 1 do acc := f !acc (unsafe_get a i) done;
    !acc
end
