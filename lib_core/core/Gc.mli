(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*             Damien Doligez, projet Para, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)

(* Module [Gc]: memory management control *)

(* mini-ml's collector copies the live values from one half of the heap
   to the other (languages/ml/runtime): it has one kind of collection,
   which each of these runs. *)

external minor : unit -> unit = "gc_minor"
        (* Trigger a minor collection. *)
external major : unit -> unit = "gc_major"
        (* Finish the current major collection cycle. *)
external full_major : unit -> unit = "gc_full_major"
        (* Finish the current major collection cycle and perform a complete
           new cycle. *)
external compact : unit -> unit = "gc_compaction"
        (* Perform a full major collection and compact the heap. *)

(* ix: no program of ix called these, and mini-ml's runtime did not have
 * them (to restore from ocaml-light's gc.ml): the types stat and control
 * (the counters and the parameters of ocaml-light's two generations),
 * stat, get, set, print_stat. *)
