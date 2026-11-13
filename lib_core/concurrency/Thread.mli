(* ix: OCaml's Thread, for mini-ml (dune's builds take OCaml's threads
 * library, because this directory is not dune's; see plan_rio.md,
 * "Threads: the design"). It has the same names, for what ix's programs
 * use. Here the threads are cooperative: a thread runs until it waits
 * (in Event.sync, on a Mutex that is taken, in join) or says so
 * (yield), and nothing runs in between. Each thread has its own value
 * stack and machine stack. The scheduler is in this module, in OCaml,
 * over two primitives of the runtime: one makes a thread, and the other
 * switches to another thread.
 *
 * A thread must not wait in a system call (such as a read of the
 * keyboard), because all the others would wait with it. Source turns
 * what is read from a descriptor into messages on a channel.
 *
 * The scheduler is a queue and a table, and each thread is in one
 * place:
 *
 *       create, yield, wakeup put a thread at the end
 *                         |
 *                         v
 *     ready    <-- [ t3 | t1 | t4 ]      those that can run, in turn
 *       |
 *       | the first is taken, and switched to
 *       v
 *     running      t2                    only one, until it waits or yields
 *       |
 *       | sleep (Event.sync with no partner, a Mutex held by another,
 *       v        join on a thread still alive)
 *     asleep     { t5, t0 }              in no queue; wakeup moves it
 *
 * yield shows the whole of it in two lines: the caller goes to the end
 * of ready, and the first thread of ready runs. When ready is empty and
 * some threads sleep, nobody is left to wake them. Then [idle] is
 * called, which ends the program ("deadlock"), unless Source has put
 * there its wait for the outside (a key, a clock).
 *
 * A switch saves three words of the thread that leaves (the pointer of
 * its machine stack, where it returns, and the top of its value stack)
 * and puts back the other thread's. The thread that leaves is inside a
 * call to the runtime, and comes back from that call when its turn
 * comes again. The kernel switches a process at any instruction, with
 * every register to save, so a thread here costs less.
 *
 * Where it stands: mini-rio is made of threads, one for each window,
 * with the events of the mouse, the keyboard and the windows on
 * channels (Event). The JavaScript engine runs the body of an async
 * function on a thread, to stop it at an await (Js_coroutine). A
 * kernel's scheduler is the same queue with one more thing: a clock
 * that takes the processor from a process that does not give it up.
 *
 * terminology:
 * Cooperative (as here) means that a thread runs until it gives up its
 * turn. Preemptive means that a clock's interrupt, or the system, can
 * take the turn away anywhere. A coroutine is the cooperative kind
 * where the caller names the next one, instead of a scheduler choosing
 * it. The cooperative kind is the easy one to write and to reason
 * about: between two waits a thread is alone, so a structure it changes
 * there needs no lock.
 *
 * cs-history:
 * The coroutine comes from Melvin Conway (1963). He wrote each pass of
 * a compiler as a main program, and the passes handed control to one
 * another, whereas a subroutine has a master and returns to it.
 *
 * others:
 * Plan 9's libthread is this design in C: within a process the
 * threads are cooperative and talk by channels, and what must wait
 * in the system is given a process of its own, as Source does. Go
 * kept the channels and made the threads preemptive, spread over the
 * processors by its runtime. OCaml's threads library, which dune's
 * builds of ix link, uses the system's threads under one lock, so
 * that only one at a time runs OCaml code.
 *
 * References: M. E. Conway, "Design of a Separable
 * Transition-Diagram Compiler", CACM 6(7), 1963; thread(2) of Plan 9;
 * John Reppy's Concurrent ML, for the channels of Event (see Event's
 * header). *)

type t

(* [create f x] makes a new thread, which runs [f x] when its turn
 * comes. The thread ends when f returns or raises (the exception is
 * printed on the standard error, as in OCaml). It raises Failure
 * "Thread.create: too many threads" when 256 threads are alive already
 * (the runtime's STACKS, each thread with its two stacks; the place of
 * a finished thread is used again). *)
val create : ('a -> 'b) -> 'a -> t

(* ix: [create_large f x] is the same, but with stacks as large as the
 * program's: its value stack (4 MB on Plan 9) and a machine stack as
 * large, where the stacks of [create] are 128 KB and 256 KB. For either
 * kind of thread, going past the end of a stack is a fatal error,
 * "stack overflow". It is for a thread that does what the program's
 * first thread did, deep recursions and all, such as mini-netscape's
 * worker (Worker_spawn). It is not OCaml's, whose threads have the
 * system's stacks (8 MB on Linux). *)
val create_large : ('a -> 'b) -> 'a -> t
val self : unit -> t
(* The thread's number: 0 for the program's first thread. *)
val id : t -> int
(* Ends the calling thread. *)
val exit : unit -> unit
(* Gives the turn to the other threads; the caller's turn comes
 * again. *)
val yield : unit -> unit
(* Waits until the thread has ended. *)
val join : t -> unit

(* These are not OCaml's: they are for Mutex, Condition and Event, with
 * the names of ocaml-light's user-level threads, which those modules
 * were written with. With sleep, the caller sleeps until another thread
 * wakes it up. Those modules set critical_section, but nothing reads
 * it, because nothing preempts a thread here. *)
val critical_section : bool ref
val sleep : unit -> unit
val wakeup : t -> unit

(* What the scheduler does when no thread can run and some sleep. By
 * default the program ends, with "deadlock". Source puts here its wait
 * for a message from the system. *)
val idle : (unit -> unit) ref
