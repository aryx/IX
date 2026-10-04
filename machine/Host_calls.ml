(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* What a personality (Linux, Plan9) asks of the host: a record of
 * functions and their types. No Unix here, so that the machine runs
 * where OCaml runs, a browser included (plan_pi.md, decision 9); Host
 * implements it on Unix. File descriptors are the host's own, as
 * qemu-user has them. *)

type errno = int
type 'a r = ('a, errno) result

type kind = Reg | Dir | Chr | Blk | Fifo | Lnk | Sock

type stat = {
  dev : int; ino : int; kind : kind; perm : int; nlink : int; uid : int; gid : int; rdev : int;
  size : int; atime : float; mtime : float; ctime : float;
}

type dirent = { d_ino : int; d_name : string; d_kind : kind }

type disposition = Default | Ignore | Catch

type t = {
  read : int -> int -> string r;
  write : int -> string -> int r;
  openat : int option -> string -> int -> int -> int r;  (* a directory fd (not AT_FDCWD), path, Linux's flags, mode *)
  close : int -> unit r;
  fstat : int -> stat r;
  stat : string -> stat r;                      (* by path, following links *)
  lseek : int -> int -> int -> int r;
  unlink : string -> unit r;
  rmdir : string -> unit r;
  chdir : string -> unit r;
  mkdir : string -> int -> unit r;
  access : string -> int -> unit r;
  fchmod : int -> int -> unit r;
  ftruncate : int -> int -> unit r;
  rename : string -> string -> unit r;
  dup : int -> int r;
  dup2 : int -> int -> int r;
  getcwd : unit -> string;
  getpid : unit -> int;
  pipe : unit -> (int * int) r;
  fork : unit -> int r;
  wait4 : int -> int -> (int * int) r;         (* pid, options: pid, Linux's status *)
  kill : int -> int -> unit r;
  readdir : int -> dirent option r;             (* a directory fd's next entry *)
  isatty : int -> bool;
  now : unit -> float;
  sleep : float -> unit;
  setitimer : float -> float -> float * float;  (* interval, value: the old ones *)
  signal : int -> disposition -> unit;
}
