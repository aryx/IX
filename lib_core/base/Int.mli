(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                         The OCaml programmers                          *)
(*                                                                        *)
(*   Copyright 2018 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Integer values.

    Integers are {!Sys.int_size} bits wide and use two's complement
    representation. All operations are taken modulo
    2{^[Sys.int_size]}. They do not fail on overflow.

    @since 4.08 *)

(** {1:ints Integers} *)

type t = int
(** The type for integer values. *)

val zero : int
(** [zero] is the integer [0]. *)

val one : int
(** [one] is the integer [1]. *)

val minus_one : int
(** [minus_one] is the integer [-1]. *)





external div : int -> int -> int = "%divint"
(** [div x y] is the division [x / y]. See {!Stdlib.( / )} for details. *)

external rem : int -> int -> int = "%modint"
(** [rem x y] is the remainder [x mod y]. See {!Stdlib.( mod )} for details. *)



val abs : int -> int
(** [abs x] is the absolute value of [x]. That is [x] if [x] is positive
    and [neg x] if [x] is negative. {b Warning.} This may be negative if
    the argument is {!min_int}. *)

val max_int : int
(** [max_int] is the greatest representable integer,
    [2{^[Sys.int_size - 1]} - 1]. *)

val min_int : int
(** [min_int] is the smallest representable integer,
    [-2{^[Sys.int_size - 1]}]. *)








(** {1:preds Predicates and comparisons} *)

val equal : t -> t -> bool
(** [equal x y] is [true] iff [x = y]. *)

val compare : t -> t -> int
(** [compare x y] is {!Stdlib.compare}[ x y] but more efficient. *)

(** {1:convert Converting} *)

external to_float : int -> float = "%floatofint"
(** [to_float x] is [x] as a floating point number. *)

external of_float : float -> int = "%intoffloat"
(** [of_float x] truncates [x] to an integer. The result is
    unspecified if the argument is [nan] or falls outside the range of
    representable integers. *)

val of_string : string -> int option
(** [of_string s] is [Some s] if [s] can be parsed to an integer
    in the range representable by the type [int] (note that this
    depends on {!Sys.int_size}) and [None] otherwise.

    The string may start with an optional ['-'] or ['+'] sign, and may
    be followed by an optional prefix that specifies the base in which
    the number is expressed. If there is not prefix or if the prefix
    is [0u] or [0U] it is expressed in decimal. If the prefix is [0x]
    or [0X] it is expressed in hexadecimal. If the prefix is [0o] or
    [0O] it is expressed in octal. If the prefix is [0b] or [0B] it is
    expressed in binary.

    When the [0u] or [0U] prefix is used, the represented number may
    exceed {!max_int} or {!min_int} in which case it wraps around
    modulo 2{^[Sys.int_size]} like arithmetic operations do.

    The ['_'] (underscore) character can appear anywhere between two
    digits of the number. *)

val to_string : int -> string
(** [to_string x] is the written representation of [x] in decimal. *)

(* ix: OCaml's later functions, those ix's programs use *)

val min : int -> int -> int
val max : int -> int -> int

(* ix: no program of ix called these, taken out (to restore from OCaml 4.14's int.ml):
 * neg, add, sub, mul, succ, pred, logand, logor, logxor, lognot,
 * shift_left, shift_right, shift_right_logical. *)
