(* Linux's side of a process (plan_debugger.md, stage 8a; the third side
 * of decision 12). What /proc/$pid's files give mini-acid on Plan 9 is
 * got with ptrace on Linux, as plan9port's libmach does (Linux.c):
 *
 *     Plan 9's /proc/$pid      Linux
 *     mem                      /proc/$pid/mem (a tracer's to read, write)
 *     regs (a Ureg)            PTRACE_GETREGSET (arm64's user_pt_regs)
 *     ctl: start, waitstop     PTRACE_CONT, waitpid
 *     ctl: stop, kill          SIGSTOP, SIGKILL
 *     a hung child's exec      PTRACE_TRACEME, then execv: stopped
 *
 * The signals' numbers are Linux's (5 is SIGTRAP, which a breakpoint
 * raises). There are two implementations: linux/'s (for dune, with a C
 * stub, linux/ptrace.c) and linux/mini-ml/'s (for the mkfile, with no
 * ptrace and available set to false). *)

(* whether this build has ptrace (dune's mini-acid on Linux) *)
val available : bool

(* runs a program traced, stopped at its exec, with its addresses not
 * randomized, and returns its pid *)
val spawn : < Cap.fork; Cap.exec; .. > -> string -> string array -> int

(* reads the bytes of a process's registers, and writes them back *)
val getregs : int -> string
val setregs : int -> string -> unit

(* continues a process, delivering a signal (0 for none) *)
val cont : int -> int -> unit

(* waits for a process. The result says whether it was stopped by a
 * signal (> 0, the signal's number), exited (-1 - its status), or was
 * killed (-1000 - the signal). *)
val wait : int -> int

(* sends a signal (19 is SIGSTOP, 9 is SIGKILL) *)
val signal : < Cap.kill; .. > -> int -> int -> unit
