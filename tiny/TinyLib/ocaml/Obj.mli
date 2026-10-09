(* TinyLib: lib_core/core/Obj, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [Obj]: operations on internal representations of values *)

(* Not for the casual user. *)

type t

external repr : 'a -> t = "%identity"
external obj : t -> 'a = "%identity"
external magic : 'a -> 'b = "%identity"

external tag : t -> int = "obj_tag"
external size : t -> int = "%obj_size"
external field : t -> int -> t = "%obj_field"
external set_field : t -> int -> t -> unit = "%obj_set_field"
(* a block of that tag and that many fields, each 0 *)
external new_block : int -> int -> t = "obj_block"

(* from 3.0 *)
external is_int : t -> bool = "%obj_is_int"

(* from 2.02 *)
val string_tag : int
val double_tag : int
