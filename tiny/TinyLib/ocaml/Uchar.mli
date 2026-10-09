(* TinyLib: lib_core/base/Uchar, the part the tiny programs call (tiny/TinyLib/README.md) *)
(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                           Daniel C. Buenzli                            *)
(*                                                                        *)
(*   Copyright 2014 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Unicode characters.

    @since 4.03 *)

type t
(** The type for Unicode characters. *)




(** /* *)


(** /* *)



(* ix: OCaml's later functions, those ix's programs use *)

(* a decoded character: whether the bytes were one (else it is U+FFFD),
 * how many bytes were read, the character; and the two made *)
type utf_decode
val utf_decode : int -> t -> utf_decode

(* ix: no program of ix called these, taken out (to restore from OCaml 4.14's uchar.ml):
 * bom, succ, pred, unsafe_to_char, hash. *)
