(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The kernel's calls for a program in ML: mlsys.c's functions, as
 * externals, their values ML's; -1 when the kernel refuses. On the
 * host these names are ../host/TinyCalls.ml's. An external a program
 * does not call costs it nothing. (TinyWindows.ml says its own: OCaml
 * checks that file alone.) *)
external u_write : int -> string -> int = "u_write"
external u_read : int -> int -> string = "u_read"
external u_ready : int array -> int -> int -> int = "u_ready"
external u_ticks : unit -> int = "u_ticks"
external u_time : unit -> int = "u_time"
external u_seed : unit -> int = "u_seed"
external u_stat : string -> string = "u_stat"
external u_open : string -> int -> int = "u_open"
external u_close : int -> int = "u_close"
external u_dup : int -> int = "u_dup"
external u_seek : int -> int -> int -> int = "u_seek"
external u_pipe : unit -> int = "u_pipe"
external u_chdir : string -> int = "u_chdir"
external u_mkdir : string -> int = "u_mkdir"
external u_unlink : string -> int = "u_unlink"
external u_link : string -> string -> int = "u_link"
external u_getcwd : unit -> string = "u_getcwd"
external u_rawcons : int -> int = "u_rawcons"
external u_fork : unit -> int = "u_fork"
external u_exec : string -> string list -> int = "u_exec"
external u_spawn : string -> string list -> int = "u_spawn"
external u_waits : unit -> int = "u_waits"
external u_kill : int -> int = "u_kill"
external u_trace : int -> int = "u_trace"
external u_getpid : unit -> int = "u_getpid"
external u_argc : unit -> int = "u_argc"
external u_arg : int -> string = "u_arg"
external u_flush : unit -> unit = "u_flush"
external u_dial : string -> int -> int = "u_dial"
