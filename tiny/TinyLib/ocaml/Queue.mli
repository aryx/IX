(* TinyLib: lib_core/collections/Queue, the part the tiny programs call (tiny/TinyLib/README.md) *)
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


(* Module [Queue]: first-in first-out queues *)

(* This module implements queues (FIFOs), with in-place modification. *)

type 'a t
        (* The type of queues containing elements of type ['a]. *)

exception Empty
        (* Raised when [take] is applied to an empty queue. *)

val create: unit -> 'a t
        (* Return a new queue, initially empty. *)
val add: 'a -> 'a t -> unit
        (* [add x q] adds the element [x] at the end of the queue [q]. *)
val take: 'a t -> 'a
        (* [take q] removes and returns the first element in queue [q], or
           raises [Empty] if the queue is empty. *)

(* ix: OCaml's later functions, those ix's programs use *)

val is_empty : 'a t -> bool

(* add and take, under their other names *)
val pop : 'a t -> 'a

(* take, None for an empty queue *)
