(* TinyKernel's processes. Each process has a slot (its frame, where
 * kentry.s saves its registers at a trap), a memory (a KMemory space),
 * its descriptors and its current directory. This module also gives
 * the kernel access to a process's memory, checking each address
 * against the process's space.
 *
 *     Ready ──a call that must wait──► Waiting f ──f () = true──► Ready
 *       │                                (the scheduler tries f again)
 *       ├──exit, kill──► gone: its slot and memory are freed at once;
 *       │                (parent, pid, status) goes in [ended], for
 *       │                the parent's wait
 *       └──a stop for its tracer──► Stopped ──the tracer resumes it──► Ready
 *
 * A call that must wait keeps the rest of its work in Waiting, as a
 * closure that returns whether it could finish. There is no kernel
 * stack per process to sleep on; the scheduler simply calls the
 * closure again.
 *
 * A process that ends is freed at once, both its slot and its memory.
 * What its parent's wait needs from it, its pid and its status, is kept
 * as a record of three numbers in [ended], which the wait removes.
 * There are no zombies: a parent that never waits (as www never waits
 * for the play it starts) costs one small record per child, not one of
 * the 16 slots and a memory partition.
 *
 * plan9-is-cleaner:
 * Unix keeps an ended process as a zombie: its entry in the process
 * table stays, holding its status, until its parent waits (and an
 * orphan is handed to init, which waits for it). This costs a state of
 * its own, which the scheduler, kill, tracing and the console's owner
 * must each skip; it holds a slot; and a parent that does not wait
 * leaks zombies, which programs work around by setting SIGCHLD to
 * SIG_IGN or by forking twice. Plan 9's pexit frees the process and
 * puts a Waitq, a message, on its parent's list (dropping any past 128),
 * and wait reads the next message: the status is data, not a process.
 * We do the same here, with no limit.
 *
 * others:
 * Unix's and Plan 9's kernels sleep in the middle of a call, on the
 * process's own kernel stack; so does xv6 (sleep, wakeup). Keeping a
 * closure instead is what Mach did from 1991 (Draves and others,
 * "Using continuations to implement thread management and
 * communication in operating systems"): a blocked thread gives up its
 * stack, and the rest of its work is a function to call.
 *)

(* Waiting holds the rest of the system call, which returns true when
 * it could finish. Stopped lasts until the tracer resumes the process. *)
type state = Ready | Waiting of (unit -> bool) | Stopped

(* [since]: while waiting for a child, the value of deaths when it last
 * looked. [core] is 0 also while core 0 handles its trap. [doomed]: killed
 * on another core, it ends at its next trap. [cmd] and [memory], for
 * /dev/ps, come from exec, or from the parent after a fork. *)
type proc = {
  slot : int;
  mem : KMemory.space;
  pid : int;
  mutable state : state;
  mutable parent : int option;
  mutable fds : (int * KFiles.file) list;
  mutable cwd : string list;
  mutable since : int option;
  mutable traced : KFiles.trace option;
  mutable core : int option;
  mutable doomed : bool;
  mutable cmd : string;
  mutable memory : int;
}

(* In the order the scheduler goes through them. *)
val procs : proc list ref
val next_pid : int ref
val deaths : int ref

(* Children not waited for yet, oldest first, dropped if the parent
 * ends. Only this is kept, not the process: www's helpers, never waited
 * for, would otherwise hold a slot and 4 MB each. *)
type ending = { end_parent : int; end_pid : int; end_status : int }
val ended : ending list ref

(* Registers r1..r15, and the pc as 16. *)
val reg : proc -> int -> int
val set_reg : proc -> int -> int -> unit

(* Raised for an address outside the process's memory. *)
exception Bad

(* [user p va n] is the kernel's address of n user bytes. [user_out],
 * for bytes the kernel writes, also raises Bad for the text (read-only
 * with segments). *)
val user : proc -> int -> int -> int
val user_out : proc -> int -> int -> int

(* [user_iter p va n f] calls f a off k for each piece of the buffer:
 * kernel address a, offset off in the buffer, length k. *)
val user_iter : proc -> int -> int -> (int -> int -> int -> 'a) -> unit

val user_write : proc -> int -> string -> unit
val ustr : proc -> int -> string

(* Raises No_room when there is none. *)
val free_slot : unit -> int

(* [fdalloc p f] gives f the lowest free descriptor. *)
val fd : proc -> int -> KFiles.file
val fdalloc : proc -> KFiles.file -> int

(* One more or one less descriptor on a file. Pipes count their ends;
 * a draw connection's last one frees its images. *)
val share : KFiles.file -> unit
val drop : KFiles.file -> unit

(* The links to other machines; [net] holds the connections. *)
val links : KFiles.link list ref
val next_link : int ref
val net : KNetwork.net_stack

(* [traced_proc t] is None once the process ended. [detach t] puts back
 * the words under its breakpoints. *)
val traced_proc : KFiles.trace -> proc option
val detach : KFiles.trace -> unit
