(* TinyLib: lib_core/base/Float, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * OCaml. Copyright 2018 INRIA. LGPL 2.1, with the linking exception of OCaml's LICENSE. *)

(** Floating-point arithmetic: IEEE 754 double precision (64 bits).
    No operation raises on overflow, underflow or division by zero:
    [infinity], [neg_infinity] and [nan] are returned, and propagate. *)

external of_int : int -> float = "%floatofint"

type t = float

(* ix: OCaml's later functions, those ix's programs use *)
