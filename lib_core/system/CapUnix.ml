(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CapUnix.mli *)

let fork _caps = Unix.fork
let execv _caps = Unix.execv
let execve _caps = Unix.execve
let wait _caps = Unix.wait
let waitpid _caps = Unix.waitpid
let kill _caps = Unix.kill
let chdir _caps = Unix.chdir
let environment _caps = Unix.environment
let gettimeofday _caps = Unix.gettimeofday
let time _caps = Unix.time
let sleepf _caps = Unix.sleepf
let pipe _caps = Unix.pipe
let getpid _caps = Unix.getpid
let getcwd _caps = Unix.getcwd
