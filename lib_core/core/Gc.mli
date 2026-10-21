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

type control = { mutable minor_heap_size : int; mutable major_heap_increment : int; mutable space_overhead : int; mutable verbose : int }
        (* OCaml's record, as ocaml-light has it. Here [space_overhead]
           is the one that is read: how much more than what is alive
           the heap may be, in hundredths of it (100, the least: twice;
           700: eight times, and a collection, which copies all that is
           alive, that much less often). [minor_heap_size] is the
           heap's size now, in words; [set] does not change it. *)
external get : unit -> control = "gc_get"
external set : control -> unit = "gc_set"
        (* [Gc.set { (Gc.get ()) with space_overhead = 700 }], as in OCaml. *)

type stat = {
  minor_words : float; promoted_words : float; major_words : float; minor_collections : int; major_collections : int;
  heap_words : int; heap_chunks : int; live_words : int; live_blocks : int; free_words : int; free_blocks : int;
  largest_free : int; fragments : int; compactions : int; top_heap_words : int; stack_size : int; forced_major_collections : int }
        (* OCaml's record. Here, of mini-ml's two halves: [heap_words]
           a half's size now (the program holds both: twice that, once
           both have been written), [top_heap_words] the largest so
           far, [live_words] what was alive after the last collection
           (OCaml's [stat] counts it now; [quick_stat] says 0),
           [minor_collections] and [major_collections] the
           collections; the counters mini-ml has not, 0 (the floats)
           or what a heap of one piece says. *)
val stat : unit -> stat
val quick_stat : unit -> stat
        (* the same here: nothing is counted that is not kept *)
