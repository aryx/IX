(* mini-xv6's open files (xv6's file.c, pipe.c, console.c): what a file
 * descriptor names, a pipe's end, an inode, or the console (the one
 * device, major 1), each read and written its own way.
 *
 * Bytes cross here as OCaml strings: a read returns what it read (the
 * system call copies it to the user), a write gets what the user gave.
 *
 * Three things with close names, in three tables:
 *
 *     a process's ofile      the open files      the inodes in use
 *     (Types.proc, NOFILE)   (here, NFILE)       (Fs, NINODE)
 *
 *     sh    0 --------.
 *           1 -------. '---> Device console
 *     cat   0 ------. '----> Pipe_end p, writable --.
 *           1 --.    '-----> Pipe_end p, readable --+--> p: 512 bytes
 *                '---------> Inode_file, off 37 ------> inode 12
 *
 * A descriptor is a small number, an index in its process's table;
 * it names an open file, which has the offset and the mode; the open
 * file names what holds the bytes. fork and dup copy the first arrow
 * (the offset is then shared: two processes writing to one file do
 * not overwrite each other), open makes a new open file on the same
 * inode (an offset of its own).
 *
 * A pipe is a buffer of 512 bytes and two counters that only grow:
 * nwrite - nread bytes are in it, the next read at nread mod 512. A
 * reader of an empty pipe sleeps while a writing end is open, and
 * reads 0, the end of file, once none is: which is why a shell must
 * close the ends it does not use.
 *
 * design:
 * Types.file_kind is a variant, each case with what it needs; xv6's
 * struct file has a tag and the three pointers, of which the tag
 * says which one is not null. read and write are then a match, the
 * one place where the kinds are told apart: a file descriptor is
 * Unix's abstraction of a source or sink of bytes, and a program
 * that reads descriptor 0 does not know which kind it has.
 *
 * cs-history:
 * The pipe was asked for by Doug McIlroy from 1964 (programs coupled
 * "like garden hose") and written by Ken Thompson in 1973, for the
 * third edition; the | of the shell came with it. Descriptors 0, 1
 * and 2 left open by the parent are what made it need no change in
 * the programs.
 *
 * plan9-is-cleaner:
 * xv6 has one device, found by an inode's major number in a switch;
 * Unix has a table of them and mknod. In Plan 9 a device is a file
 * server in the kernel with a name of its own (#c the console, #|
 * the pipes), and what an open file names is always a channel to a
 * server: mini-9pi's Dev and Kchan, where this module's three cases
 * are one.
 *
 * References: the xv6 book's "File descriptor layer" and its first
 * chapter, where the shell's use of pipes and redirections is worked
 * out; xv6's file.c, pipe.c, console.c. M. D. McIlroy's memorandum
 * of 1964 (kept on Dennis Ritchie's pages at Bell Labs). Dennis
 * Ritchie, "The Evolution of the Unix Time-sharing
 * System" (1979), which tells how pipes came. *)

(* the console's input: a character from the UART (consoleintr) *)
val intr : int -> unit

(* a new open file (NFILE at most): its kind, readable, writable *)
val alloc : Types.file_kind -> bool -> bool -> Types.file option
val dup : Types.file -> Types.file
(* the last reference gone: the pipe's end closed, the inode let go *)
val close : Types.file -> unit

(* a new pipe's two ends, reading and writing *)
val pipe : unit -> (Types.file * Types.file) option

(* where a read's bytes go, where a write's come from: the user's
 * memory, at an offset in its buffer (Syscall's copyout, copyin): false
 * or None when out of reach, and the read or write stops there *)
type dst = int -> string -> bool
type src = int -> int -> string option

(* at most [n] bytes (a pipe's reader waits for one, the console's for
 * a line), or -1; the bytes written, or -1. A file's offset moves *)
val read : Types.file -> int -> dst -> int
val write : Types.file -> int -> src -> int

(* an inode's, a device's inode *)
val inode : Types.file -> Types.inode option
