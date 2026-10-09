(* TinyLib: lib_core/base/Int, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* The OCaml programmers
 * OCaml. Copyright 2018 INRIA. LGPL 2.1, with the linking exception of OCaml's LICENSE. *)

(** Integer values: {!Sys.int_size} bits wide, two's complement; the
    operations are modulo 2{^[Sys.int_size]} and do not fail on overflow. *)

type t = int

external div : int -> int -> int = "%divint"

external rem : int -> int -> int = "%modint"

(* ix: OCaml's later functions, those ix's programs use *)
