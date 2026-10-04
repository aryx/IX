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

val min : t
(** [min] is U+0000. *)

val max : t
(** [max] is U+10FFFF. *)


val rep : t
(** [rep] is U+FFFD, the
    {{:http://unicode.org/glossary/#replacement_character}replacement}
    character. *)



val is_valid : int -> bool
(** [is_valid n] is [true] iff [n] is a Unicode scalar value (i.e. *)

val of_int : int -> t
(** [of_int i] is [i] as a Unicode character. @raise Invalid_argument if [i]
    does not satisfy {!is_valid}. *)

(** /* *)
val unsafe_of_int : int -> t
(** /* *)

val to_int : t -> int
(** [to_int u] is [u] as an integer. *)

val is_char : t -> bool
(** [is_char u] is [true] iff [u] is a latin1 OCaml character. *)

val of_char : char -> t
(** [of_char c] is [c] as a Unicode character. *)

val to_char : t -> char
(** [to_char u] is [u] as an OCaml latin1 character. @raise Invalid_argument
    if [u] does not satisfy {!is_char}. *)

(** /* *)

val equal : t -> t -> bool
(** [equal u u'] is [u = u']. *)

val compare : t -> t -> int
(** [compare u u'] is [Pervasives.compare u u']. *)


(* ix: OCaml's later functions, those ix's programs use *)

(* a decoded character: whether the bytes were one (else it is U+FFFD),
 * how many bytes were read, the character; and the two made *)
type utf_decode
val utf_decode_is_valid : utf_decode -> bool
val utf_decode_length : utf_decode -> int
val utf_decode_uchar : utf_decode -> t
val utf_decode : int -> t -> utf_decode
val utf_decode_invalid : int -> utf_decode

(* ix: no program of ix called these, taken out (to restore from OCaml 4.14's uchar.ml):
 * bom, succ, pred, unsafe_to_char, hash. *)
