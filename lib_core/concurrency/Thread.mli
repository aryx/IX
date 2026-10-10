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
 * reads as a channel's messages.
 *
 * The scheduler is a queue and a table. A thread is in one place:
 *
 *       create, yield, wakeup put a thread at the end
 *                         |
 *                         v
 *     ready    <-- [ t3 | t1 | t4 ]      those that can run, in turn
 *       |
 *       | the first taken, and switched to
 *       v
 *     running      t2                    one, until it waits or yields
 *       |
 *       | sleep (Event.sync with no partner, a Mutex held by another,
 *       v        join on a thread still alive)
 *     asleep     { t5, t0 }              in no queue: wakeup's to move
 *
 * yield is the whole of it in two lines: the caller goes to the end
 * of ready, and the first of ready runs. When ready is empty and
 * some sleep, nobody is left to wake them: [idle] is called, which
 * ends the program ("deadlock") unless Source has put there its wait
 * for the outside (a key, a clock).
 *
 * A switch saves three words of the thread that leaves (its machine
 * stack's pointer, where it returns, its value stack's top) and puts
 * back the other's: the thread is inside a call of the runtime's,
 * and comes back from that call when its turn returns. A process is
 * switched by the kernel at any instruction, with every register to
 * save: a thread here costs less.
 *
 * Where it stands: mini-rio is made of them, a thread a window and
 * the mouse's, the keyboard's and the windows' events on channels
 * (Event); the JavaScript engine runs an async function's body on
 * one, to stop it at an await (Js_coroutine). A kernel's scheduler
 * is the same queue with one thing more, a clock that takes the
 * processor from a process that does not give it.
 *
 * terminology:
 * Cooperative (here): a thread runs until it gives its turn.
 * Preemptive: a clock's interrupt, or the system, takes it away
 * anywhere. A coroutine is the cooperative kind with the next one
 * named by the caller, not chosen by a scheduler. The first is the
 * easy one to write and to reason with: between two waits a thread
 * is alone, so a structure it changes there needs no lock.
 *
 * cs-history:
 * The coroutine is Melvin Conway's (1963): the passes of a compiler
 * written each as a main program, handing control to one another,
 * where a subroutine has a master and returns to it.
 *
 * others:
 * Plan 9's libthread is this design in C: within a process the
 * threads are cooperative and talk by channels, and what must wait
 * in the system is given a process of its own, as Source does. Go
 * kept the channels and made the threads preemptive, spread over the
 * processors by its runtime. OCaml's threads library, which dune's
 * builds of ix link, uses the system's threads under one lock, so
 * that one at a time runs OCaml code.
 *
 * References: M. E. Conway, "Design of a Separable
 * Transition-Diagram Compiler", CACM 6(7), 1963; thread(2) of Plan 9;
 * John Reppy's Concurrent ML for Event's channels (Event's header). *)

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
