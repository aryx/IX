(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1997 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)


(* Module [Marshal]: marshaling of data structures *)

(* This module provides functions to encode arbitrary data structures
   as sequences of bytes, which can then be written on a file or
   sent over a pipe or network connection.  The bytes can then
   be read back later, possibly in another process, and decoded back
   into a data structure. The format for the byte sequences
   is compatible across all machines for a given version of Objective Caml.

   Warning: marshaling is currently not type-safe. The type
   of marshaled data is not transmitted along the value of the data,
   making it impossible to check that the data read back possesses the
   type expected by the context. In particular, the result type of
   the [Marshal.from_*] functions is given as ['a], but this is
   misleading: the returned Caml value does not possess type ['a]
   for all ['a]; it has one, unique type which cannot be determined
   at compile-type.  The programmer should explicitly give the expected
   type of the returned value, using the following syntax:
                     [(Marshal.from_channel chan : type)].
   Anything can happen at run-time if the object in the file does not
   belong to the given type.

   The representation of marshaled values is not human-readable,
   and uses bytes that are not printable characters. Therefore,
   input and output channels used in conjunction with [Marshal.to_channel]
   and [Marshal.from_channel] must be opened in binary mode, using e.g.
   [open_out_bin] or [open_in_bin]; channels opened in text mode will
   cause unmarshaling errors on platforms where text channels behave
   differently than binary channels, e.g. Windows. *)

type extern_flags =
    No_sharing                          (* Don't preserve sharing *)
  | Closures                            (* Send function closures *)
        (* The flags to the [Marshal.to_*] functions below. *)

val to_channel: out_channel -> 'a -> extern_flags list -> unit
        (* [Marshal.to_channel chan v flags] writes the representation of
           [v] on channel [chan]. *)

val to_string: 'a -> extern_flags list -> string
        (* [Marshal.to_string v flags] returns a string containing the
           representation of [v] as a sequence of bytes. *)

val to_buffer: bytes -> int -> int -> 'a -> extern_flags list -> int
        (* [Marshal.to_buffer buff ofs len v flags] marshals the value [v],
           storing its byte representation in the string [buff], starting at
           character number [ofs], and writing at most [len] characters. *)

val from_channel: in_channel -> 'a
        (* [Marshal.from_channel chan] reads from channel [chan] the byte
           representation of a structured value, as produced by one of the
           [Marshal.to_*] functions, and reconstructs and returns the
           corresponding value. *)

val from_string: string -> int -> 'a
        (* [Marshal.from_string buff ofs] unmarshals a structured value like
           [Marshal.from_channel] does, except that the byte representation
           is not read from a channel, but taken from the string [buff],
           starting at position [ofs]. *)

val header_size : int
val data_size : bytes -> int -> int
val total_size : bytes -> int -> int
        (* The bytes representing a marshaled value are composed of a fixed-
           size header and a variable-sized data part, whose size can be
           determined from the header. *)

(* ix: OCaml's later names: to_string and from_string, for bytes *)
val to_bytes : 'a -> extern_flags list -> bytes
val from_bytes : bytes -> int -> 'a
