(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The kernel's calls for a program in ML: mlsys.c's functions, as
 * externals, their values ML's; -1 when the kernel refuses. Given to
 * tiny-ml before the files that name them: TinyLibPlayground.ml (the
 * first four: on the host its names are ../host/TinyCalls.ml's) and
 * TinyLibSystem.ml. An external a program does not call costs it
 * nothing. (TinyWindows.ml says its own: OCaml checks that file
 * alone.) *)
external u_write : int -> string -> int = "u_write"
external u_read : int -> int -> string = "u_read"
external u_ready : int array -> int -> int -> int = "u_ready"
external u_ticks : unit -> int = "u_ticks"
external u_open : string -> int -> int = "u_open"
external u_close : int -> int = "u_close"
external u_dup : int -> int = "u_dup"
external u_pipe : unit -> int = "u_pipe"
external u_chdir : string -> int = "u_chdir"
external u_fork : unit -> int = "u_fork"
external u_exec : string -> string list -> int = "u_exec"
external u_waits : unit -> int = "u_waits"
external u_getpid : unit -> int = "u_getpid"
external u_argc : unit -> int = "u_argc"
external u_arg : int -> string = "u_arg"
external u_flush : unit -> unit = "u_flush"
