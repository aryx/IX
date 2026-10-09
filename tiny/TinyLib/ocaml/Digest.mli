(* TinyLib: lib_core/base/Digest, the part the tiny programs call (tiny/TinyLib/README.md) *)
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

(* $Id *)

(* Module [Digest]: MD5 message digest *)

(* This module provides functions to compute 128-bit ``digests'' of
   arbitrary-length strings or files. The digests are cryptographic
   quality: it is very hard, given a digest, to forge a string having
   that digest. The algorithm used is MD5. *)

type t = string
        (* The type of digests: 16-character strings. *)
val string: string -> t
        (* Return the digest of the given string. *)
external channel: in_channel -> int -> t = "md5_chan"
        (* [Digest.channel ic len] reads [len] characters from channel [ic]
           and returns their digest. *)
val file: string -> t
        (* Return the digest of the file whose name is given. *)

(* ix: OCaml's later functions, those ix's programs use *)

(* the digest's 16 bytes as 32 hexadecimal digits *)
val to_hex : t -> string
