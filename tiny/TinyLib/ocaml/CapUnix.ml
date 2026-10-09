(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See CapUnix.mli *)

let fork _caps = Unix.fork
let execv _caps = Unix.execv
let execve _caps = Unix.execve
let wait _caps = Unix.wait
let waitpid _caps = Unix.waitpid
let chdir _caps = Unix.chdir
let environment _caps = Unix.environment
