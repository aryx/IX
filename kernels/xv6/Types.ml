(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-xv6's data (plan_kernel.md): the types every module shares, as
 * xv6's headers (proc.h, file.h, fs.h) are (a page's: kernels/lib_machine's
 * Page), but as OCaml says
 * them. A process's state carries what matters in it (what it sleeps
 * on); a file is a pipe's end, an inode, or a device, not a tag and
 * three pointers; what a process waits for is a channel, a variant
 * compared by what it names (xv6's is any address).
 *
 * The same structure in C and here, a process's state:
 *
 *     enum procstate { UNUSED, USED, SLEEPING, RUNNABLE, RUNNING,
 *                      ZOMBIE };
 *     struct proc { enum procstate state; void *chan; ... };
 *
 *     type state = Runnable | Running | Sleeping of chan | Zombie
 *
 * In C chan means something in one state of six and the reader must
 * know which; here it exists in that state only. UNUSED is no state:
 * a slot with no process is None in Proc.procs. USED, a process
 * being made, is not needed: nothing can run between a process's
 * first field and its last.
 *
 * design:
 * "Make illegal states unrepresentable" (Yaron Minsky's phrase for
 * it): a type that has a value only for what can happen needs no
 * check that it did not, and no comment saying which fields go
 * together. Most of what OCaml gains over xv6's C is in this file.
 * What the types do not say is what stays on the disk: an inode
 * here is a number and a count, its fields read where they are
 * (Fs). *)

(* (No Types.mli: the module is its types.) *)

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

(* an inode's type, on the disk a short (fs.h's T_DIR 1, T_FILE 2,
 * T_DEVICE 3; 0 a free inode) *)
type itype = Free | Dir | File | Devnode

(* an inode in use: its number and how many hold it; the rest (type,
 * size, block addresses) stays on the disk, read and written there
 * (Fs.ml: the disk is RAM) *)
type inode = { inum : int; mutable iref : int }

(* a pipe's buffer: 512 bytes, nread and nwrite counting forever (xv6's) *)
type pipe = {
  pdata : Bytes.t;
  mutable nread : int;
  mutable nwrite : int;
  mutable readopen : bool;
  mutable writeopen : bool;
}

type file_kind = Pipe_end of pipe | Inode_file of inode | Device of inode * int (* its major *)

type file = {
  kind : file_kind;
  mutable fref : int;
  readable : bool;
  writable : bool;
  mutable off : int;
}

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* what a sleeping process waits for *)
type chan =
  | Ticks                   (* sleep(n), a tick *)
  | Child_of of int         (* wait: a child of this pid exiting *)
  | Pipe_readable of pipe
  | Pipe_writable of pipe
  | Console_input

type state = Runnable | Running | Sleeping of chan | Zombie

type proc = {
  pid : int;
  slot : int;                   (* its kernel stack and trap frame (machine.c) *)
  mutable state : state;
  mutable pgdir : int;          (* its first-level table's physical address *)
  mutable sz : int;             (* its memory: [0, sz) *)
  mutable parent : int;         (* a pid; 0 for init *)
  mutable killed : bool;
  mutable xstate : int;         (* exit's status, for the parent's wait *)
  ofile : file option array;    (* NOFILE *)
  mutable cwd : inode;
  mutable name : string;
}
