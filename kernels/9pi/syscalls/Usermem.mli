(* The user's memory as the system calls see it: bytes and strings
 * read from it, written to it, their pages faulted in first
 * (validaddr); Error ebadarg when an address is not the process's.
 * Also what the calls share: a vlong argument, the lengths' limits.
 *
 * A system call's argument that is an address is a number a program
 * made up. The kernel can write anywhere; so every such number goes
 * through here, where it is looked up in the process's own table
 * (Mmu, after Fault has given the pages their segments allow) and
 * refused when it is not there. A read into the address 0x80000000
 * fails with "bad arg in system call"; without the check it would
 * write a line typed over whatever is there.
 *
 * design:
 * The bytes are copied, into an OCaml string or out of one, and the
 * kernel never keeps a user's address to use later: by then the
 * process may have changed its memory (brk, exec), or be another's.
 * A C kernel does the same with copyin and copyout; what it cannot
 * do is make the mistake impossible, and here an address is an int
 * that nothing but these functions can follow. *)

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
