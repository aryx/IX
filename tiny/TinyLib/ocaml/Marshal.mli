(* TinyLib: lib_core/core/Marshal, the part the tiny programs call (tiny/TinyLib/README.md) *)
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


val to_string: 'a -> extern_flags list -> string
        (* [Marshal.to_string v flags] returns a string containing the
           representation of [v] as a sequence of bytes. *)



val from_string: string -> int -> 'a
        (* [Marshal.from_string buff ofs] unmarshals a structured value like
           [Marshal.from_channel] does, except that the byte representation
           is not read from a channel, but taken from the string [buff],
           starting at position [ofs]. *)

val header_size : int

(* ix: OCaml's later names: to_string and from_string, for bytes *)
val from_bytes : bytes -> int -> 'a
