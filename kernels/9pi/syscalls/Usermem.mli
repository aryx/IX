(* The user's memory as the system calls see it: bytes and strings
 * read from it, written to it, their pages faulted in first
 * (validaddr); Error ebadarg when an address is not the process's.
 * Also what the calls share: a vlong argument, the lengths' limits. *)

open Types
open Errors

(* ERRMAX, a note's or an error's size; a path's *)
val errmax : int
val maxpath : int

(* [user_string p addr max]: a string, to its NUL (max bytes at most) *)
val user_string : proc -> int -> int -> string
val user_read : proc -> int -> int -> string
val user_write : proc -> int -> string -> unit

(* snprint into the user's buffer: at most n-1 bytes and a NUL; how
 * many *)
val user_snprint : proc -> int -> int -> string -> int

(* a vlong argument (two words, the low first): None for -1 (the
 * channel's own offset); offsets past 1GB are not the Pi1's ints *)
val offset : int -> int -> int option
