(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The files' system calls (principia's sysfile.c): open, create,
 * close, pread, pwrite, seek, dup, pipe, fd2path, stat, fstat, wstat,
 * fwstat, remove, chdir; the namespace's: bind, mount, unmount. Names
 * are the user's strings already read (Systab), buffers the user's
 * addresses. *)

open Types

val sysopen : proc -> string -> int -> int
(* [syscreate p name mode perm] *)
val syscreate : proc -> string -> int -> int -> int
val sysclose : proc -> int -> int
(* [syspread p fd buf n off]: off None, the channel's own *)
val syspread : proc -> int -> int -> int -> int option -> int
val syspwrite : proc -> int -> int -> int -> int option -> int
(* [sysseek p ret fd lo hi type]: the new offset written at ret (a
 * vlong: 5c's results) *)
val sysseek : proc -> int -> int -> int -> int -> int -> int
val sysdup : proc -> int -> int -> int
val syspipe : proc -> int -> int
(* [sysfd2path p fd buf n] *)
val sysfd2path : proc -> int -> int -> int -> int
(* [sysstat p name buf n], [sysfstat p fd buf n]: the entry, or its
 * size alone when it does not fit *)
val sysstat : proc -> string -> int -> int -> int
val sysfstat : proc -> int -> int -> int -> int
val syswstat : proc -> string -> int -> int -> int
val sysfwstat : proc -> int -> int -> int -> int
val sysremove : proc -> string -> int
val syschdir : proc -> string -> int
(* [sysbind p new old flag] *)
val sysbind : proc -> string -> string -> int -> int
(* [sysmount p fd old flag aname]: the server on fd attached (devmnt) *)
val sysmount : proc -> int -> string -> int -> string -> int
(* [sysunmount p new old]: new a user's string (0: all of old's) *)
val sysunmount : proc -> int -> string -> int
