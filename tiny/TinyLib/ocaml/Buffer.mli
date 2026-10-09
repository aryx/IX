(* TinyLib: lib_core/base/Buffer, the part the tiny programs call (tiny/TinyLib/README.md) *)
(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*  Pierre Weis and Xavier Leroy, projet Cristal, INRIA Rocquencourt   *)
(*                                                                     *)
(*  Copyright 1999 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)

(* ported from 3.12 *)


(** Extensible string buffers.

   This module implements string buffers that automatically expand
   as necessary.  It provides accumulative concatenation of strings
   in quasi-linear time (instead of quadratic time when strings are
   concatenated pairwise).
*)

type t
(** The abstract type of buffers. *)

val create : int -> t
(** [create n] returns a fresh buffer, initially empty. *)

val contents : t -> string
(** Return a copy of the current contents of the buffer. *)

val to_bytes : t -> bytes
(** Return a copy of the current contents of the buffer. *)



val nth : t -> int -> char
(** get the n-th character of the buffer. Raise [Invalid_argument] if index
    out of bounds *)

val length : t -> int
(** Return the number of characters currently contained in the buffer. *)

val clear : t -> unit
(** Empty the buffer. *)


val add_char : t -> char -> unit
(** [add_char b c] appends the character [c] at the end of the buffer [b]. *)

val add_string : t -> string -> unit
(** [add_string b s] appends the string [s] at the end of the buffer [b]. *)

val add_substring : t -> string -> int -> int -> unit
(** [add_substring b s ofs len] takes [len] characters from offset [ofs] in
    string [s] and appends them at the end of the buffer [b]. *)

val add_subbytes : t -> bytes -> int -> int -> unit
(** [add_subbytes b s ofs len] takes [len] characters from offset [ofs] in
    byte sequence [s] and appends them at the end of buffer [b]. @raise
    Invalid_argument if [ofs] and [len] do not designate a valid range of
    [s]. *)





(* ix: OCaml's later functions, those ix's programs use *)

val add_bytes : t -> bytes -> unit

(* the buffer cut to its first len characters *)

(* an integer's bytes added, the low one first *)
val add_uint8 : t -> int -> unit
val add_uint16_le : t -> int -> unit
val add_int32_le : t -> int32 -> unit
val add_int64_le : t -> int64 -> unit

(* a character's UTF-8 bytes added *)

(* ix: no program of ix called these, taken out (to restore from OCaml 4.14's buffer.ml):
 * add_substitute. *)
