(* TinyLib: lib_core/base/Int, the part the tiny programs call (tiny/TinyLib/README.md) *)
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




external div : int -> int -> int = "%divint"
(** [div x y] is the division [x / y]. *)

external rem : int -> int -> int = "%modint"
(** [rem x y] is the remainder [x mod y]. *)





(** {1:preds Predicates and comparisons} *)



(** {1:convert Converting} *)





(* ix: OCaml's later functions, those ix's programs use *)

val max : int -> int -> int

(* ix: no program of ix called these, taken out (to restore from OCaml 4.14's int.ml):
 * neg, add, sub, mul, succ, pred, logand, logor, logxor, lognot,
 * shift_left, shift_right, shift_right_logical. *)
