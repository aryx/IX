(* TinyLib: lib_core/collections/Queue, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [Queue]: first-in first-out queues, modified in place *)

type 'a t

exception Empty
        (* Raised when [take] is applied to an empty queue. *)

val create: unit -> 'a t
val add: 'a -> 'a t -> unit
        (* At the end. *)
val take: 'a t -> 'a
        (* The first element, removed; raises [Empty]. *)

(* ix: OCaml's later functions, those ix's programs use *)

val is_empty : 'a t -> bool

(* take, under its other name *)
val pop : 'a t -> 'a
