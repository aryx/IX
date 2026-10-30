(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ptrace.mli; the calls are linux/ptrace.c's *)

external spawn_ : string -> string array -> int = "ml_ptrace_spawn"
external getregs : int -> string = "ml_ptrace_getregs"
external setregs : int -> string -> unit = "ml_ptrace_setregs"
external cont : int -> int -> unit = "ml_ptrace_cont"
external wait : int -> int = "ml_ptrace_wait"
external signal_ : int -> int -> unit = "ml_ptrace_signal"

let available = true
let spawn (_ : < Cap.fork; Cap.exec; .. >) path argv = spawn_ path argv
let signal (_ : < Cap.kill; .. >) pid s = signal_ pid s
