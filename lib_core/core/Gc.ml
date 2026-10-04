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
