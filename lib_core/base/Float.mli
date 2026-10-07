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

(** {1 Floating-point arithmetic}

    OCaml's floating-point numbers follow the
    IEEE 754 standard, using double precision (64 bits) numbers.
    Floating-point operations never raise an exception on overflow,
    underflow, division by zero, etc.  Instead, special IEEE numbers
    are returned as appropriate, such as [infinity] for [1.0 /. 0.0],
    [neg_infinity] for [-1.0 /. 0.0], and [nan] ('not a number')
    for [0.0 /. 0.0].  These special numbers then propagate through
    floating-point computations as expected: for instance,
    [1.0 /. infinity] is [0.0], and any arithmetic operation with [nan]
    as argument returns [nan] as result.
*)

external neg : float -> float = "%negfloat"
(** Unary negation. *)

external abs : float -> float = "%absfloat"
(** [abs f] returns the absolute value of [f]. *)

external of_int : int -> float = "%floatofint"
(** Convert an integer to floating-point. *)

external to_int : float -> int = "%intoffloat"
(** Truncate the given floating-point number to an integer. *)

external of_string : string -> float = "float_of_string"
(** Convert the given string to a float. Raise [Failure "float_of_string"]
    if the given string is not a valid representation of a float. *)

val to_string : float -> string
(** Return the string representation of a floating-point number. *)

external pow : float -> float -> float = "power_float" "pow"
(*[@@unboxed] [@@noalloc]*)
(** Exponentiation. *)

external sqrt : float -> float = "sqrt_float" "sqrt"
(*[@@unboxed] [@@noalloc]*)
(** Square root. *)

external exp : float -> float = "exp_float" "exp" (*[@@unboxed] [@@noalloc]*)
(** Exponential. *)

external log : float -> float = "log_float" "log" (*[@@unboxed] [@@noalloc]*)
(** Natural logarithm. *)

(** Base 10 logarithm. *)

external cos : float -> float = "cos_float" "cos" (*[@@unboxed] [@@noalloc]*)
(** Cosine. *)

external sin : float -> float = "sin_float" "sin" (*[@@unboxed] [@@noalloc]*)
(** Sine. *)

external tan : float -> float = "tan_float" "tan" (*[@@unboxed] [@@noalloc]*)
(** Tangent. *)

(** Arc cosine. *)

(** Arc sine. *)

external atan : float -> float = "atan_float" "atan"
(*[@@unboxed] [@@noalloc]*)
(** Arc tangent.
    Result is in radians and is between [-pi/2] and [pi/2]. *)

external atan2 : float -> float -> float = "atan2_float" "atan2"
(*[@@unboxed] [@@noalloc]*)
(** [atan2 y x] returns the arc tangent of [y /. x].  The signs of [x]
    and [y] are used to determine the quadrant of the result.
    Result is in radians and is between [-pi] and [pi]. *)

(*[@@unboxed] [@@noalloc]*)
(** [hypot x y] returns [sqrt(x *. x + y *. y)], that is, the length
    of the hypotenuse of a right-angled triangle with sides of length
    [x] and [y], or, equivalently, the distance of the point [(x,y)]
    to origin.  If one of [x] or [y] is infinite, returns [infinity]
    even if the other is [nan]. *)

(** Hyperbolic cosine.  Argument is in radians. *)

(** Hyperbolic sine.  Argument is in radians. *)

(** Hyperbolic tangent.  Argument is in radians. *)

external ceil : float -> float = "ceil_float" "ceil"
(*[@@unboxed] [@@noalloc]*)
(** Round above to an integer value.
    [ceil f] returns the least integer value greater than or equal to [f].
    The result is returned as a float. *)

external floor : float -> float = "floor_float" "floor"
(*[@@unboxed] [@@noalloc]*)
(** Round below to an integer value.
    [floor f] returns the greatest integer value less than or
    equal to [f].
    The result is returned as a float. *)

type t = float
(** An alias for the type of floating-point numbers. *)

val compare: t -> t -> int
(** [compare x y] returns [0] if [x] is equal to [y], a negative integer if
    [x] is less than [y], and a positive integer if [x] is greater than [y]. *)

val equal: t -> t -> bool
(** The equal function for floating-point numbers, compared using
    {!compare}. *)

(* ix: OCaml's later functions, those ix's programs use *)

(* a float's significand, of 0.5 to 1 (1 excluded), and its exponent *)
val frexp : float -> float * int

val is_nan : float -> bool

val pi : float
(* the length of (x, y): sqrt (x *. x +. y *. y), computed so (infinity
 * where a square overflows, which C's hypot avoids) *)
val hypot : float -> float -> float
(* x -. n *. y, n the quotient x /. y toward zero: x's sign (C's fmod) *)
val rem : float -> float -> float

(* to an integer, toward zero; to the nearest, a half away from zero *)
val trunc : float -> float
val round : float -> float

(* nan if one of the two is; -0.0 is less than 0.0 *)
val min : float -> float -> float
val max : float -> float -> float

(* x * y + z, rounded once (not twice, as x *. y +. z) *)
val fma : float -> float -> float -> float

(* ix: no program of ix called these, taken out (to restore from OCaml
 * 4.14's float.ml): add, sub, mul, div (the operators are Pervasives's),
 * log10, acos, asin, cosh, sinh, tanh. Already out, in comments here before
 * (ocaml-light's compiler did not have them): copysign, modf,
 * ldexp, expm1, log1p, classify_float (and its type, fpclass),
 * of_string_opt. *)
