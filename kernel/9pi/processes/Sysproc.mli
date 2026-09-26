(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The processes' system calls (principia's sysproc.c): rfork, exec,
 * exits, await, brk, sleep, alarm, notify and noted (their portable
 * parts: the note's delivery is the arch's, Syscall), rendezvous,
 * errstr; and pexit, pprint, which the arch's notes use too. *)

open Types

(* the process's end (pexit): its files closed, its parent told (a
 * wait record), its memory freed; the boot process's is the kernel's
 * panic *)
val exits : proc -> string -> unit

(* a message on the process's standard error, "text pid: " first
 * (devcons_pprint) *)
val pprint : proc -> string -> unit

val sysrfork : proc -> int -> int
(* [sysexec p name argv]: argv the user's array of strings *)
val sysexec : proc -> string -> int -> int
(* [sysexits p status]: status a user's string (0: none) *)
val sysexits : proc -> int -> int
val sysawait : proc -> int -> int -> int
val sysbrk : proc -> int -> int
val syssleep : proc -> int -> int
val sysalarm : proc -> int -> int
val sysnotify : proc -> int -> int
(* sysnoted: its argument checked, kept for after the call's return
 * (arch__noted: Syscall's noted) *)
val sysnoted : proc -> int -> int
val noted_arg : int option ref
val sysrendezvous : proc -> int -> int -> int
val syserrstr : proc -> int -> int -> int

(* noted's arguments (NCONT, NDFLT, NSAVE, NRSTR) *)
val ncont : int
val ndflt : int
val nsave : int
val nrstr : int
