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


(* Module [Callback]: registering Caml values with the C runtime *)

(* This module allows Caml values to be registered with the C runtime
   under a symbolic name, so that C code can later call back registered
   Caml functions, or raise registered Caml exceptions. *)

val register: string -> 'a -> unit
        (* [Callback.register n v] registers the value [v] under the name
           [n]. *)

val register_exception: string -> exn -> unit
        (* [Callback.register_exception n exn] registers the exception
           contained in the exception value [exn] under the name [n]. *)
