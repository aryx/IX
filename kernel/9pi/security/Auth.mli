(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The authentication's system calls (principia's security/auth.c):
 * fauth (an authentication file on a server's connection: devmnt's
 * auth) and fversion (the connection's 9P version negotiated). *)

open Types

(* [sysfauth p fd aname]: the authentication file's descriptor *)
val sysfauth : proc -> int -> string -> int
(* [sysfversion p fd msize buf n]: the version the user's buffer holds *)
val sysfversion : proc -> int -> int -> int -> int -> int
