(* Linux's side of a process (plan_debugger.md, stage 8a; decision 12's
 * third side): what /proc/$pid's files give mini-acid on Plan 9, by
 * ptrace on Linux, as plan9port's libmach does (Linux.c):
 *
 *     Plan 9's /proc/$pid      Linux
 *     mem                      /proc/$pid/mem (a tracer's to read, write)
 *     regs (a Ureg)            PTRACE_GETREGSET (arm64's user_pt_regs)
 *     ctl: start, waitstop     PTRACE_CONT, waitpid
 *     ctl: stop, kill          SIGSTOP, SIGKILL
 *     a hung child's exec      PTRACE_TRACEME, then execv: stopped
 *
 * A signal's numbers are Linux's (5 SIGTRAP, a breakpoint's). Two
 * implementations: linux/'s (dune's, a C stub, linux/ptrace.c) and
 * linux/mini-ml/'s (the mkfile's: no ptrace, available false). *)

(* whether this build has ptrace (mini-acid on Linux, dune's) *)
val available : bool

(* a program run traced, stopped at its exec, its addresses not
 * randomized: its pid *)
val spawn : < Cap.fork; Cap.exec; .. > -> string -> string array -> int

(* its registers' bytes, and written back *)
val getregs : int -> string
val setregs : int -> string -> unit

(* continued, a signal delivered (0: none) *)
val cont : int -> int -> unit

(* waited for: stopped by a signal (> 0, its number), exited (-1 - its
 * status), killed (-1000 - the signal) *)
val wait : int -> int

(* a signal sent (19 SIGSTOP, 9 SIGKILL) *)
val signal : < Cap.kill; .. > -> int -> int -> unit
