(* TinyKernel's system calls, plus what they need: ending a process and
 * loading a program into a process's memory. A system call is a trap
 * of kind Trap_sys. The call's number is the operand of the sys
 * instruction (the trap's value), its arguments are in r1..r3, and its
 * result is put back in r1.
 *
 *     0 exit    1 write   2 read     3 fork    4 exec     5 wait
 *     6 getpid  7 open    8 close    9 pipe    10 dup     11 mkdir
 *     12 unlink 13 chdir  14 kill    15 ready  16 ticks   17 box
 *     18 dial   19 listen 20 getcwd  21 link   22 rawcons 23 trace
 *     24 seek   25 date   26 stat    27 seed   28 spawn
 *
 * A call that may have to wait (a read, a wait, a fork when no process
 * slot is free) is tried at once. If it cannot finish, it becomes the
 * process's Waiting state, and the scheduler tries it again later (see
 * KProcs.mli).
 *
 * A buffer passed to a call is used in place in the user's memory when
 * it is in one piece (inside one partition). Otherwise it is copied
 * through the kernel's bounce buffer (see the layout in TinyKernel.mli),
 * as Linux's copy_from_user and xv6's copyin copy every call's buffer.
 *
 * plan9-is-cleaner:
 * A link to another machine and a trace are both files behind a
 * descriptor (from dial and trace), read and written like any other
 * file. Unix instead has sockets and ptrace, each with calls of its
 * own. spawn is fork and exec in one call, like POSIX's posix_spawn.
 *)

(* [exit_proc p status] closes p's descriptors, orphans its children,
 * keeps status for its parent (or frees its slot). The end of the first
 * process is the end of the machine. *)
val exit_proc : KProcs.proc -> int -> unit

(* [load_prog p node argv] places argv where start.s expects it. It fails
 * with Bad, p unchanged, if node is not a program or there is no room. *)
val load_prog :
  KProcs.proc -> KFiles.node option -> string list -> unit

(* What kill(pid) does: the process ends as on a fault, with status -1. *)
val kill : KProcs.proc -> unit

(* [call p n] runs system call n. A tracer that asked to stop at calls is
 * told before and after. *)
val call : KProcs.proc -> int -> unit

(* [waited p] is for a traced process whose waiting call just ended. It
 * stops the process and returns true if its tracer asked to stop at a
 * call's end or to step. *)
val waited : KProcs.proc -> bool
