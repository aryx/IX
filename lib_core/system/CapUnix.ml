(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See CapUnix.mli *)

let fork _caps = Unix.fork
let execv _caps = Unix.execv
let execve _caps = Unix.execve
let wait _caps = Unix.wait
let waitpid _caps = Unix.waitpid
let kill _caps = Unix.kill
let chdir _caps = Unix.chdir
let environment _caps = Unix.environment
