(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*         Gabriel Scherer, projet Parsifal, INRIA Saclay                 *)
(*                                                                        *)
(*   Copyright 2019 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Either type: the simplest sum, a value of one type or of another. *)

type ('a, 'b) t = Left of 'a | Right of 'b

val is_left : ('a, 'b) t -> bool
val is_right : ('a, 'b) t -> bool

(** [find_left (Left v)] is [Some v], [find_left (Right _)] is [None]. *)
val find_left : ('a, 'b) t -> 'a option
val find_right : ('a, 'b) t -> 'b option

(* ix: the type and what tells its two cases apart; no program of ix
 * called more (2026-10-04). OCaml 4.14's either.ml also has, to restore
 * from it: left, right (the constructors as functions), map_left,
 * map_right, map, fold, iter, for_all (by labels ~left ~right), equal,
 * compare. *)
