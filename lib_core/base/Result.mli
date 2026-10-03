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

(** Result values: either a value [Ok v] or an error [Error e]. The type
    itself is Pervasives's [result], so that [Ok] and [Error] need no
    module's name. *)

type ('a, 'e) t = ('a, 'e) result = Ok of 'a | Error of 'e

val is_ok : ('a, 'e) result -> bool
val is_error : ('a, 'e) result -> bool

(** [get_ok r] is [v] if [r] is [Ok v] and raises [Invalid_argument] otherwise. *)
val get_ok : ('a, 'e) result -> 'a
val get_error : ('a, 'e) result -> 'e

(** [bind r f] is [f v] if [r] is [Ok v] and [r] if [r] is [Error _]. *)
val bind : ('a, 'e) result -> ('a -> ('b, 'e) result) -> ('b, 'e) result

val to_option : ('a, 'e) result -> 'a option

(* ix: the type and its core; no program of ix called more (2026-10-04).
 * OCaml 4.14's result.ml also has, to restore from it: ok, error (the
 * constructors as functions), value (a default for an Error), join,
 * map, map_error, fold (by labels ~ok ~error), iter, iter_error,
 * equal, compare, to_list, to_seq. *)
