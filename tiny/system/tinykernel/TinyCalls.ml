(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The kernel's calls for a program in ML: mlsys.c's functions, as
 * externals, their values ML's; -1 when the kernel refuses. On the
 * host these names are ../sdl/ or ../stub/TinyCalls.ml's
 * (../TinyCalls.mli), but for those this file has beyond the
 * interface: TinyLibSystem's (fork, exec, pipe...), and TinyDebugger's
 * and TinyTracer's (trace). An external a program does not call costs
 * it nothing. (TinyWindows.ml says its own: OCaml checks that file
 * alone.) *)

(*****************************************************************************)
(* Descriptors *)
(*****************************************************************************)

(* a program's first descriptors (../TinyCalls.mli) *)
let fd_stdin = 0
let fd_stdout = 1
let fd_stderr = 2
let fd_draw = 3
let fd_mouse = 4

external u_write : int -> string -> int = "u_write"
external u_read : int -> int -> string = "u_read"
external u_ready : int array -> int -> int -> int = "u_ready"
external u_rawcons : int -> int = "u_rawcons"
external u_flush : unit -> unit = "u_flush"
external u_dup : int -> int = "u_dup"
external u_pipe : unit -> int = "u_pipe"

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

external u_open : string -> int -> int = "u_open"

(* u_open's flags (../TinyCalls.mli) *)
let o_read = 0
let o_anew = 0x601
let o_write = 0x201
let o_read_write = 0x202

external u_close : int -> int = "u_close"
external u_seek : int -> int -> int -> int = "u_seek"
external u_stat : string -> string = "u_stat"
external u_chdir : string -> int = "u_chdir"
external u_mkdir : string -> int = "u_mkdir"
external u_unlink : string -> int = "u_unlink"
external u_link : string -> string -> int = "u_link"
external u_getcwd : unit -> string = "u_getcwd"

(*****************************************************************************)
(* The clock *)
(*****************************************************************************)

external u_ticks : unit -> int = "u_ticks"
external u_time : unit -> int = "u_time"
external u_seed : unit -> int = "u_seed"

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

external u_fork : unit -> int = "u_fork"
external u_exec : string -> string list -> int = "u_exec"
external u_spawn : string -> string list -> int = "u_spawn"
external u_waits : unit -> int = "u_waits"
external u_kill : int -> int = "u_kill"
external u_trace : int -> int = "u_trace"
external u_getpid : unit -> int = "u_getpid"
external u_argc : unit -> int = "u_argc"
external u_arg : int -> string = "u_arg"

(*****************************************************************************)
(* The network *)
(*****************************************************************************)

external u_dial : string -> int -> int = "u_dial"
