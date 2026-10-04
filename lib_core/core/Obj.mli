(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)

(* Module [Obj]: operations on internal representations of values *)

(* Not for the casual user. *)

type t

external repr : 'a -> t = "%identity"
external obj : t -> 'a = "%identity"
external magic : 'a -> 'b = "%identity"

external is_block : t -> bool = "obj_is_block"
external tag : t -> int = "obj_tag"
external size : t -> int = "%obj_size"
external field : t -> int -> t = "%obj_field"
external set_field : t -> int -> t -> unit = "%obj_set_field"

(* from 3.0 *)
external is_int : t -> bool = "%obj_is_int"

(* from 2.02 *)
val string_tag : int
val double_tag : int

(* ix: no program of ix called these, taken out (to restore from ocaml-light's obj.ml):
 * new_block, no_scan_tag, closure_tag, infix_tag, object_tag,
 * abstract_tag, double_array_tag, final_tag. *)
