(* TinyLib: lib_core/core/Obj, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [Obj]: operations on internal representations of values *)

(* Not for the casual user. *)

type t

external repr : 'a -> t = "%identity"
external obj : t -> 'a = "%identity"
external magic : 'a -> 'b = "%identity"

(* from 3.0 *)

(* from 2.02 *)
