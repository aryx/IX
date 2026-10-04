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

val sub : t -> int -> int -> string
(** [Buffer.sub b off len] returns (a copy of) the substring of the current
    contents of the buffer [b] starting at offset [off] of length [len]
    bytes. *)

val blit : t -> int -> string -> int -> int -> unit
(** [Buffer.blit src srcoff dst dstoff len] copies [len] characters from the
    current contents of the buffer [src], starting at offset [srcoff] to
    string [dst], starting at character [dstoff]. Raise [Invalid_argument]
    if [srcoff] and [len] do not designate a valid substring of [src], or if
    [dstoff] and [len] do not designate a valid substring of [dst]. *)

val nth : t -> int -> char
(** get the n-th character of the buffer. Raise [Invalid_argument] if index
    out of bounds *)

val length : t -> int
(** Return the number of characters currently contained in the buffer. *)

val clear : t -> unit
(** Empty the buffer. *)

val reset : t -> unit
(** Empty the buffer and deallocate the internal string holding the buffer
    contents, replacing it with the initial internal string of length [n]
    that was allocated by {!Buffer.create} [n]. *)

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


val add_buffer : t -> t -> unit
(** [add_buffer b1 b2] appends the current contents of buffer [b2] at the
    end of buffer [b1]. *)

val add_channel : t -> in_channel -> int -> unit
(** [add_channel b ic n] reads exactly [n] character from the input channel
    [ic] and stores them at the end of buffer [b]. Raise [End_of_file] if
    the channel contains fewer than [n] characters. *)

val output_buffer : out_channel -> t -> unit
(** [output_buffer oc b] writes the current contents of buffer [b] on the
    output channel [oc]. *)

(* ix: OCaml's later functions, those ix's programs use *)

val add_bytes : t -> bytes -> unit

(* the buffer cut to its first len characters *)
val truncate : t -> int -> unit

(* an integer's bytes added, the low one first *)
val add_uint8 : t -> int -> unit
val add_uint16_le : t -> int -> unit
val add_int32_le : t -> int32 -> unit
val add_int64_le : t -> int64 -> unit

(* a character's UTF-8 bytes added *)
val add_utf_8_uchar : t -> Uchar.t -> unit

(* ix: no program of ix called these, taken out (to restore from OCaml 4.14's buffer.ml):
 * add_substitute. *)
