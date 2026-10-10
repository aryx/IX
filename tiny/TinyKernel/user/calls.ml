(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyCalls's names on tiny-machine, for TinyPlayground.ml: mlsys.c's
 * system calls. Given to tiny-ml before it (../../TinyCalls.ml is the
 * host's). *)
external u_write : int -> string -> int = "u_write"
external u_read : int -> int -> string = "u_read"
external u_ready : int array -> int -> int -> int = "u_ready"
external u_ticks : unit -> int = "u_ticks"
