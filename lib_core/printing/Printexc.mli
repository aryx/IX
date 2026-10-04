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

(* Facilities for printing exceptions. *)

val to_string : exn -> string
        (* [Printexc.to_string e] returns a string representation of [e]. *)

val print: ('a -> 'b) -> 'a -> 'b
        (* Same as [catch], but re-raise the stray exception after printing
           it, instead of aborting the program. *)

val catch: ('a -> 'b) -> 'a -> 'b
        (* [Printexc.catch fn x] applies [fn] to [x] and returns the result. *)

(* backport of 3.10.2 *)
val get_backtrace: unit -> string
(** [Printexc.get_backtrace ()] returns a string containing the same
    exception backtrace that [Printexc.print_backtrace] would print. *)


(* partial port of 4.01 *)
(** {6 Raw backtraces} *)

type raw_backtrace

(** The abstract type [backtrace] stores exception backtraces in a low-level
    format, instead of directly exposing them as string as the
    [get_backtrace()] function does. *)

val get_raw_backtrace: unit -> raw_backtrace
(* val print_raw_backtrace: out_channel -> raw_backtrace -> unit *)
val raw_backtrace_to_string: raw_backtrace -> string

val get_callstack: int -> raw_backtrace

(* partial port of 4.05 *)
val raise_with_backtrace: exn -> raw_backtrace -> 'a
