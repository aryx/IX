(* TinyKernel's system calls: a process's trap with c_sys, its number
 * the sys instruction's (the trap's value), its arguments in r1..r3,
 * its result put back in r1; and what they need, a process ended, a
 * program loaded in a process's memory.
 *
 *     0 exit    1 write   2 read     3 fork    4 exec     5 wait
 *     6 getpid  7 open    8 close    9 pipe    10 dup     11 mkdir
 *     12 unlink 13 chdir  14 kill    15 ready  16 ticks   17 box
 *     18 dial   19 listen 20 getcwd  21 link   22 rawcons 23 trace
 *     24 seek   25 date   26 stat    27 seed   28 spawn
 *
 * A call that may wait (a read, a wait, a fork with no slot free) is
 * tried at once and, when it cannot finish, left as the process's
 * Waiting state, tried again by the scheduler (TinyKernelProcs.mli).
 * A buffer is the user's memory as it is when it is in one piece (a
 * partition's), else copied through the kernel's bounce (TinyKernel.mli's
 * layout), as Linux's copy_from_user and xv6's copyin copy every call's.
 *
 * plan9-is-cleaner:
 * a link to another machine and a trace are files of a descriptor
 * (dial, trace), read and written as any other, where Unix has sockets
 * and ptrace, each with calls of its own. spawn is fork and exec at
 * once, as POSIX's posix_spawn.
 *)

(* [exit_proc p status]: its descriptors closed, its children orphans,
 * its status for its parent, or its slot free; the first process's end
 * is the machine's *)
val exit_proc : TinyKernelProcs.proc -> int -> unit

(* [load_prog p node argv]: the program of node in p's memory, its
 * arguments as start.tm finds them (Bad if it is no program, or if
 * there is no room: p left as it was) *)
val load_prog :
  TinyKernelProcs.proc -> TinyKernelFiles.node option -> string list -> unit

(* kill(pid)'s: the process ended as a fault ends one, its status -1 *)
val kill : TinyKernelProcs.proc -> unit

(* [call p n]: system call n of p, its tracer told before and after
 * when it stops at its calls *)
val call : TinyKernelProcs.proc -> int -> unit

(* a traced process whose wait ended, stopped if its tracer asked for
 * the call's end or a step *)
val waited : TinyKernelProcs.proc -> bool
