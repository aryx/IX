(* TinyKernel's processes: each a slot (its frame, where entry.tm saves
 * its registers at a trap), a memory (TinyKernelMemory's space), its
 * descriptors and its directory; and what reaches a process's memory
 * from the kernel, an address checked against its space.
 *
 *     Ready ──a call that must wait──► Waiting f ──f () true──► Ready
 *       │                                (the scheduler tries f again)
 *       ├──exit, kill──► gone, its slot and memory free at once; its
 *       │                (parent, pid, status) in [ended], for the
 *       │                parent's wait
 *       └──a stop for its tracer──► Stopped ──the tracer resumes it──► Ready
 *
 * A call that waits keeps the rest of itself in Waiting, a closure that
 * says whether it could finish: there is no kernel stack per process
 * to sleep on, the scheduler calls it again.
 *
 * A process that ends is freed at once, its slot and its memory. What
 * its parent's wait needs of it, its pid and its status, is a record of
 * three numbers in [ended], taken by the wait. There is no zombie: a
 * parent that never waits (www, for the play it starts) costs a record
 * a child, not one of the 16 slots and a partition.
 *
 * plan9-is-cleaner:
 * Unix keeps an ended process as a zombie: its entry in the process
 * table stays, for its status, until its parent's wait (and an
 * orphan's goes to init, which waits for it). A state of its own,
 * which the scheduler, kill, a trace and the console's owner must each
 * skip; a slot taken (tiny-kernel's zombie kept its memory too); and a
 * parent that does not wait leaks them, which SIGCHLD set to SIG_IGN or
 * a double fork work around. Plan 9's pexit frees the process and puts
 * a Waitq, a message, on its parent's list (dropped past 128 of them),
 * and wait reads the next one: the status is data, not a process. The
 * same here, with no limit: the Zombie state and the tests for it are
 * gone.
 *
 * others:
 * Unix's and Plan 9's kernels sleep in the middle of a call, on a
 * kernel stack of the process's; xv6 too (sleep, wakeup). A closure
 * kept is what Mach did instead, from 1991 (Draves and others,
 * "Using continuations to implement thread management and
 * communication in operating systems"): a blocked thread's stack given
 * up, its rest a function to call.
 *)

(* ready to run; waiting, the rest of its system call (true when it
 * could finish); stopped for its tracer, until the tracer resumes it *)
type state = Ready | Waiting of (unit -> bool) | Stopped

(* A process: its slot (where its frame is), its memory, its pid, its
 * state, its parent's pid (0: none), its descriptors, its current
 * directory; while it waits for a child's end, how many processes had
 * ended when it last looked (-1: it waits for something else); and its
 * trace, when it is traced. The core it runs on (-1: none; 0 while core
 * 0 runs it or handles its trap), and whether it was killed there, its
 * end then at its next trap. Its command line and its memory, for
 * /dev/ps: its program's (exec's arguments, the bytes it asked for), or
 * its parent's when it was forked. *)
type proc = {
  slot : int;
  mem : TinyKernelMemory.space;
  pid : int;
  mutable state : state;
  mutable parent : int;
  mutable fds : (int * TinyKernelFiles.file) list;
  mutable cwd : string list;
  mutable since : int;
  mutable traced : TinyKernelFiles.trace option;
  mutable core : int;
  mutable doomed : bool;
  mutable cmd : string;
  mutable memory : int;
}

(* the processes, in the order the scheduler goes through them; the
 * next pid; how many have ended *)
val procs : proc list ref
val next_pid : int ref
val deaths : int ref

(* The children that ended and were not waited for yet: their parent's
 * pid, theirs, their status, the first ended first; dropped if the
 * parent ends first. (old: a Zombie state, the process kept whole for
 * its status until its parent's wait: www's helpers, never waited for,
 * held a slot and 4 MB each while www ran) *)
val ended : (int * int * int) list ref

(* a register of its frame (r1..r15, the pc as 16), read and written *)
val reg : proc -> int -> int
val set_reg : proc -> int -> int -> unit

(* an address of a process's outside its memory *)
exception Bad

(* [user p va n]: a user's address, n bytes long, as the kernel reaches
 * it; [user_out]: the same, for bytes the kernel writes there (Bad in
 * its text too, read only with segments) *)
val user : proc -> int -> int -> int
val user_out : proc -> int -> int -> int

(* [user_iter p va n f]: a user's buffer, piece by piece, f a off k for
 * each piece at the kernel's address a, off bytes into it, k long *)
val user_iter : proc -> int -> int -> (int -> int -> int -> 'a) -> unit

(* a string of the kernel's written in the user's memory; a string of
 * the user's (a path), read *)
val user_write : proc -> int -> string -> unit
val ustr : proc -> int -> string

(* a free slot (No_room when there is none) *)
val free_slot : unit -> int

(* a descriptor's file; the lowest free descriptor, given that file *)
val fd : proc -> int -> TinyKernelFiles.file
val fdalloc : proc -> TinyKernelFiles.file -> int

(* a file's one more descriptor; one less (a pipe's ends count, a
 * connection's last one frees its images) *)
val share : TinyKernelFiles.file -> unit
val drop : TinyKernelFiles.file -> unit

(* the links to other machines, the next one's number; the machine's
 * connections, TinyKernelNetwork's *)
val links : TinyKernelFiles.link list ref
val next_link : int ref
val net : TinyKernelNetwork.net_stack

(* the process a trace is of, while it has not ended; the trace ended,
 * the words under its breakpoints put back *)
val traced_proc : TinyKernelFiles.trace -> proc option
val detach : TinyKernelFiles.trace -> unit
