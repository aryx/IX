(* The processes (principia's proc.c). There is a table of slots (each
 * slot has a kernel stack and a trap frame, in kernels/lib_machine's
 * runtime.c), a run queue with its scheduler on the boot stack, and
 * sleep and wakeup on a wait_chan. There is no preemption inside the
 * kernel, and only one core is in it at a time, so there are no locks
 * here. (On the Pi 2 each core runs the scheduler, on a stack of its
 * own and on the one queue; Machine has one lock for all of the
 * kernel, taken at each entry: see plan_multicore.md. What each core
 * has of its own here is the process last readied on it, and its
 * slice.)
 *
 * A process's states (Types.state), and who changes them:
 *
 *                  rfork             the scheduler takes it
 *     (a free slot) ----> Runnable -------------------------> Running
 *                          ^  ^                                | | |
 *                          |  '------ yield, preempt ----------' | |
 *                          |          (its 100 ms over)          | |
 *                 wakeup c |                           sleep c   | |
 *                 postnote '------ Sleeping c <------------------' |
 *                                                                  |
 *     (a free slot) <----- Zombie <------- exits ------------------'
 *                  the scheduler frees the slot, once off its stack
 *
 * A context switch always goes through the scheduler, which has a
 * stack and a slot of its own (the boot's). A process calls [sched],
 * which is Machine.swtch to the scheduler's slot, and the call returns
 * much later, when the scheduler has switched back to it. So a process
 * is switched only where it asks to be, in the middle of an OCaml
 * function whose locals wait on its kernel stack:
 *
 *     cat, reading the console         the UART's interrupt
 *     Devcons' read: no line yet
 *       Proc.sleep Console_input
 *         state <- Sleeping ...
 *         sched ()  - - - - - - - ->   (other processes run, or idle)
 *                                      Devcons.intr: a line is whole
 *                                        Proc.wakeup Console_input
 *                                          cat is Runnable, queued
 *         <- - - - - - - - - - - - -   the scheduler comes to it
 *       the read looks again: a line
 *
 * A wakeup readies every sleeper on the channel, and says nothing of
 * why. The process woken looks at its condition again and may sleep
 * again (Devpipe's read and write and Devmnt's rpc are such loops). A
 * note posted to a sleeper wakes it too, and its sleep raises Error
 * [eintr]: the call it was in fails with "interrupted". This is how a
 * read that would wait for ever can be stopped.
 *
 * The order of the queue is Plan 9's. It shows on the console, which
 * is why it is kept: a process readied by another runs next (a server
 * woken by a request answers at once, and its client runs right
 * after), and a child runs before its parent goes on.
 *
 * cs-history:
 * sleep and wakeup on a channel come from Unix's first kernels:
 * sleep(chan, pri) and wakeup(chan), where chan is any address the
 * two sides agree on (the buffer's, the inode's); it is compared and
 * never followed. [wait_chan] is that address made into a variant, so
 * the compiler knows every reason a process may wait for. The idea
 * breaks with two processors (a wakeup may come between the test and
 * the sleep, and be lost), and Plan 9's own kernel replaced the
 * address by a Rendez structure with a lock and a condition function.
 * With one processor and no preemption in the kernel, the old form is
 * right again, and it is the one used here and in xv6.
 *
 * others:
 * Unix keeps a dead process as a zombie, with its slot, until its
 * parent waits for it, because the status has nowhere else to be.
 * Plan 9 copies the status into the parent's own queue when the child
 * ends (Sysproc.exits makes a waitmsg), and the child is gone at once;
 * a parent that never waits leaks a few bytes, not a process. Zombie
 * here is only the moment between exits and the scheduler's freeing
 * of the slot.
 *
 * modern:
 * There is one queue, served in turn, with a slice of 100 ms. Plan 9
 * has priorities that follow how much of its slice a process uses (the
 * interactive ones rise), and optional real-time deadlines (edf.c).
 * Linux's fair scheduler (2007) keeps a tree of processes ordered by
 * the time each has had. All of them answer a question this kernel
 * does not ask: who goes first, when many want to run. With a shell
 * and a few programs the queue is short, and the rule above for a
 * readied process is enough for a window system to feel quick.
 *
 * References: principia's Kernel.nw, the chapters on processes and
 * on scheduling. John Lions, "A Commentary on the Sixth Edition UNIX
 * Operating System" (1977): sleep, wakeup and swtch, where "You are
 * not expected to understand this." is. Rob Pike, Dave Presotto, Ken
 * Thompson and Gerard Holzmann, "Process Sleep and Wakeup on a
 * Shared-memory Multiprocessor" (EurOpen, 1991): why Plan 9 changed
 * them. The xv6 book's chapter on scheduling, for the same two calls
 * with a lock. *)

open Types

val nproc : int
val procs : proc option array

(* the running process *)
val myproc : unit -> proc

(* [kproc name] spends a pid, as 9pi's kernel process of that name
 * takes one (kgenrandom, alarm, kpager, rxmitproc; mini-9pi has none of
 * them), so that the pids are 9pi's *)
val kproc : string -> unit
(* The processes that are the kernel's own, and what each runs, by its
 * slot, for Main's process_start. Such a process may sleep, as a
 * process in a system call does, and it never goes to user mode. The
 * first one in mini-9pi is Kusb's, which makes its record. *)
val kernel_work : (int * (unit -> unit)) list ref

(* the clock's ticks (100 a second) *)
val ticks : int ref

(* a free slot, or None; and the next pid *)
val free_slot : unit -> int option
val nextpid : int ref

(* [ready p] puts a process that is ready to run at the end of the run
 * queue. When it was readied by another process, it runs next (Plan
 * 9's cooperative scheduling: cpu->readied). *)
val ready : proc -> unit

(* [sched ()] goes back to the scheduler. [sleep c] sleeps until a
 * wakeup on the channel c readies the sleepers; the CPU is given up. *)
val sched : unit -> unit
val sleep : wait_chan -> unit

(* [tsleep ms] sleeps ms milliseconds (rounded up to the next tick,
 * which is every 10ms). A note interrupts it, as it does sleep. *)
val tsleep : int -> unit

(* the error a sleep raises when a note is pending ("interrupted",
 * Plan 9's Eintr); the note is delivered after it *)
val eintr : string
val wakeup : wait_chan -> unit
(* the clock's wakeup, at each tick: it readies the sleepers on Ticks,
 * and those on Until t once the ticks reach t *)
val wakeup_ticks : unit -> unit
val yield : unit -> unit

(* [preempt_due ()] tells whether a tick should preempt: the running
 * process's 100ms are over and another is ready (hzsched). [preempt]
 * then gives up the CPU, without the cooperative handing over. *)
val preempt_due : unit -> bool
val preempt : unit -> unit

(* what the scheduler does when nothing runs (Main's waits for an
 * interrupt and handles it) *)
val idle : (unit -> unit) ref

(* [scheduler ()] runs the processes for ever, the first of the run
 * queue each time (Plan 9's order: a new process runs before its parent
 * goes on). It frees a dead process's slot once the process is off its
 * kernel stack (Zombie). *)
val scheduler : unit -> unit
(* how many processes each core's scheduler switched to *)
val switches : int array

(* a live process, by its pid *)
val find : int -> proc option

(* [postnote p msg flag] (Plan 9's postnote) queues the note, NNOTE at
 * most, and returns false when the queue is full. A note that kills,
 * when p has no handler for it or is already in its handler, is left
 * alone in the queue. It
 * interrupts p's sleep, and gives up p's rendezvous, whose value is
 * then -1. *)
val postnote : proc -> string -> note_flag -> bool
