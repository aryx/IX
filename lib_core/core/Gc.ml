(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Damien Doligez, projet Para, INRIA Rocquencourt          *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)

external minor : unit -> unit = "gc_minor";;
external major : unit -> unit = "gc_major";;
external full_major : unit -> unit = "gc_full_major";;
external compact : unit -> unit = "gc_compaction";;

type control = { mutable minor_heap_size : int; mutable major_heap_increment : int; mutable space_overhead : int; mutable verbose : int };;
external get : unit -> control = "gc_get";;
external set : control -> unit = "gc_set";;

type stat = {
  minor_words : float; promoted_words : float; major_words : float; minor_collections : int; major_collections : int;
  heap_words : int; heap_chunks : int; live_words : int; live_blocks : int; free_words : int; free_blocks : int;
  largest_free : int; fragments : int; compactions : int; top_heap_words : int; stack_size : int; forced_major_collections : int };;
external counters : unit -> int * int * int * int = "gc_counters";;
let quick_stat () =
  let (n, size, top, live) = counters () in
  { minor_words = 0.; promoted_words = 0.; major_words = 0.; minor_collections = n; major_collections = n;
    heap_words = size; heap_chunks = 1; live_words = live; live_blocks = 0; free_words = size - live; free_blocks = 1;
    largest_free = size - live; fragments = 0; compactions = 0; top_heap_words = top; stack_size = 0; forced_major_collections = 0 };;
let stat = quick_stat;;
