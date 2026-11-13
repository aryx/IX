(* The user's memory, as the system calls see it. Bytes and strings are
 * read from it and written to it, after their pages are faulted in
 * (validaddr). An address that is not the process's raises Error
 * ebadarg. This module also has what the calls share: reading a vlong
 * argument, and the limits on lengths.
 *
 * A system call's argument that is an address is a number a program
 * made up, and the kernel can write anywhere. So every such number goes
 * through here, where it is looked up in the process's own table (Mmu,
 * after Fault has given it the pages its segments allow) and refused
 * when it is not there. A read into the address 0x80000000 fails with
 * "bad arg in system call"; without the check, it would write the line
 * typed over whatever is there.
 *
 * design:
 * The bytes are copied, into an OCaml string or out of one, and the
 * kernel never keeps a user's address to use later: by then the
 * process may have changed its memory (brk, exec), or the address may
 * be another process's. A C kernel does the same with copyin and
 * copyout; what it cannot do is make the mistake impossible. Here an
 * address is an int that nothing but these functions can follow. *)

open Types
open Errors

(* ERRMAX, the size of a note or of an error; and the size of a path *)
val errmax : int
val maxpath : int

(* [user_string p addr max] reads a string up to its NUL (max bytes at
 * most) *)
val user_string : proc -> int -> int -> string
val user_read : proc -> int -> int -> string
val user_write : proc -> int -> string -> unit

(* another process's memory, for its debugger (/proc/n/mem). Its pages
 * are made if they do not exist yet, and they are read and written by
 * their physical addresses (the text too, for a breakpoint), keeping
 * the instruction cache right. An address outside its segments raises
 * Error ebadarg. *)
val debug_read : proc -> int -> int -> string
val debug_write : proc -> int -> string -> unit

(* snprint into the user's buffer: at most n-1 bytes and a NUL. It
 * returns how many bytes were written, without the NUL. *)
val user_snprint : proc -> int -> int -> string -> int

(* a vlong argument (two words, the low one first). It is None for -1
 * (meaning the channel's own offset). An offset past 1GB is refused,
 * because it does not fit in the Pi1's ints. *)
val offset : int -> int -> int option
