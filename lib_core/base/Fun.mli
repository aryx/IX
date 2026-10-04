(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                         The OCaml programmers                          *)
(*                                                                        *)
(*   Copyright 2018 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Function values.

    @since 4.08 *)

external id : 'a -> 'a = "%identity"
(** [id] is the identity function. *)

val const : 'a -> ('b (* was _ *) -> 'a)
(** [const c] is a function that always returns the value [c]. *)

val flip : ('a -> 'b -> 'c) -> ('b -> 'a -> 'c)
(** [flip f] reverses the argument order of the binary function [f]. *)

val negate : ('a -> bool) -> ('a -> bool)
(** [negate p] is the negation of the predicate function [p]. *)


val protect : finally:(unit -> unit) -> (unit -> 'a) -> 'a

(* TODO
val protect : finally:(unit -> unit) -> (unit -> 'a) -> 'a
(** [protect ~finally work] invokes [work ()] and then [finally ()] before
    [work ()] returns with its value or an exception. *)

exception Finally_raised of exn
(** [Finally_raised exn] is raised by [protect ~finally work] when [finally]
    raises an exception [exn]. *)
 *)
