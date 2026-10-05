(* ix: OCaml's Thread, for mini-ml (dune's builds take OCaml's threads
 * library: this directory is not dune's; plan_rio.md, "Threads: the
 * design"). The same names, for what ix's programs use. Here the
 * threads are cooperative: one runs until it waits (Event.sync, a
 * Mutex taken, join) or says so (yield); nothing runs between. Each
 * has its value stack and its machine stack; the scheduler is this
 * module's, in OCaml, over two primitives of the runtime (a thread
 * made, a switch to another).
 *
 * A thread must not wait in a system call (a read of the keyboard):
 * all the others would wait with it. Source gives a descriptor's
 * reads as a channel's messages. *)

type t

(* [create f x]: a new thread, that runs [f x] when its turn comes; it
 * ends when f returns, or raises (the exception said on the standard
 * error, as OCaml's). Failure "Thread.create: too many threads" when
 * 256 are alive already (the runtime's STACKS: each has its two
 * stacks; a finished one's place is taken again). *)
val create : ('a -> 'b) -> 'a -> t
val self : unit -> t
(* its number: 0 for the program's first *)
val id : t -> int
(* the calling thread ends *)
val exit : unit -> unit
(* the others' turn; the caller's comes again *)
val yield : unit -> unit
(* until the thread has ended *)
val join : t -> unit

(* Not OCaml's: for Mutex, Condition and Event (ocaml-light's user-level
 * threads' own names, which those modules were written with). The
 * caller sleeps until another thread wakes it up; critical_section is
 * theirs to set (nothing preempts a thread here: it is not read). *)
val critical_section : bool ref
val sleep : unit -> unit
val wakeup : t -> unit

(* What the scheduler does when no thread can run and some sleep: by
 * default the program ends, "deadlock". Source puts here its wait for
 * a message of the system's. *)
val idle : (unit -> unit) ref
