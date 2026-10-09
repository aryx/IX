(* TinyLib: lib_core/base/Digest, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1996 INRIA. Distributed only by permission. *)

(* Module [Digest]: MD5 message digest, 128 bits, of a string or a file *)

type t = string
        (* 16 characters. *)
val string: string -> t
external channel: in_channel -> int -> t = "md5_chan"
        (* [channel ic len]: of [len] characters read from [ic]. *)
val file: string -> t

(* ix: OCaml's later functions, those ix's programs use *)

(* the digest's 16 bytes as 32 hexadecimal digits *)
val to_hex : t -> string
