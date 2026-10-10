(* The processes (principia's proc.c): a table of slots (kernels/lib_machine's
 * runtime.c: a slot's kernel stack and trap frame), a run queue and its
 * scheduler on the boot stack, sleep and wakeup on a wait_chan. One
 * core, no preemption inside the kernel: no locks.
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
 * A context switch is always through the scheduler, which has a
 * stack and a slot of its own (the boot's): a process calls [sched],
 * that is Machine.swtch to the scheduler's slot, and the call returns
 * much later, when the scheduler has switched back to it. So a
 * process is switched only where it asks, in the middle of an OCaml
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
 * A wakeup readies every sleeper of the channel, and says nothing of
 * why: the one woken looks at its condition again and may sleep
 * again (Devpipe's read and write, Devmnt's rpc are such loops). A
 * note posted to a sleeper wakes it too, and its sleep raises Error
 * [eintr]: the call it was in fails with "interrupted", which is how
 * a read that waits for ever can be got out of.
 *
 * The order of the queue is Plan 9's and shows on the console, which
 * is why it is kept: a process readied by another runs next (a
 * server woken by a request answers at once, its client right
 * after), a child runs before its parent goes on.
 *
 * cs-history:
 * sleep and wakeup on a channel are Unix's, from its first kernels:
 * sleep(chan, pri) and wakeup(chan), where chan is any address the
 * two sides agree on (the buffer's, the inode's), compared and never
 * followed. [wait_chan] is that address made a variant: the compiler
 * knows every reason a process may wait for. The idea breaks with
 * two processors (a wakeup may come between the test and the sleep,
 * and be lost), and Plan 9's own kernel replaced the address by a
 * Rendez structure with a lock and a condition function; with one
 * processor and no preemption in the kernel, the old form is right
 * again, and it is the one here and in xv6.
 *
 * others:
 * Unix keeps a dead process as a zombie, slot and all, until its
 * parent waits for it: the status has nowhere else to be. Plan 9
 * copies the status into the parent's own queue when the child ends
 * (Sysproc.exits: a waitmsg), and the child is gone at once; a parent
 * that never waits leaks a few bytes, not a process. Zombie here is
 * only the moment between exits and the scheduler's freeing the
 * slot.
 *
 * modern:
 * One queue, in turn, a slice of 100 ms. Plan 9 has priorities that
 * follow how much of its slice a process uses (the interactive ones
 * rise), and optional real-time deadlines (edf.c); Linux's fair
 * scheduler (2007) keeps a tree of processes by the time each has
 * had. All answer a question this kernel does not ask: who goes
 * first, when many want to. With a shell and a few programs the
 * queue is short, and the readied rule above is enough for a window
 * system to feel quick.
 *
 * References: principia's Kernel.nw, the chapters on processes and
 * on scheduling. John Lions, "A Commentary on the Sixth Edition UNIX
 * Operating System" (1977): sleep, wakeup and swtch, where "you are
 * not expected to understand this" is. Rob Pike, Dave Presotto, Ken
 * Thompson and Gerard Holzmann, "Process Sleep and Wakeup on a
 * Shared-memory Multiprocessor" (EurOpen, 1991): why Plan 9 changed
 * them. The xv6 book's chapter on scheduling, for the same two calls
 * with a lock. *)

open Types

val nproc : int
val procs : proc option array

(* the running process *)
val myproc : unit -> proc

(* a pid spent as 9pi's kernel process of that name takes it (kgenrandom,
 * alarm, kpager, rxmitproc: mini-9pi has none), for the pids to be
 * 9pi's *)
val kproc : string -> unit
(* claude: a process that is the kernel's own, and what it runs (it
 * may sleep, as a process in a system call; it never goes to user
 * mode): by its slot, for Main's process_start. The first of
 * mini-9pi's: Kusb's, which makes its record. *)
val kernel_work : (int * (unit -> unit)) list ref

(* the clock's ticks (100 a second) *)
val ticks : int ref

(* a free slot, or None; the next pid *)
val free_slot : unit -> int option
val nextpid : int ref

(* a process ready to run: at the run queue's end; readied by another
 * process, it runs next (Plan 9's cooperative scheduling: cpu->readied) *)
val ready : proc -> unit

(* back to the scheduler; asleep until a wakeup on the channel (the
 * sleepers readied); the CPU given up *)
val sched : unit -> unit
val sleep : wait_chan -> unit

(* asleep [ms] milliseconds (to the next tick: 10ms each; interrupted
 * by a note, as sleep) *)
val tsleep : int -> unit

(* a sleep's error when a note is pending ("interrupted": Plan 9's
 * Eintr, the note then delivered) *)
val eintr : string
val wakeup : wait_chan -> unit
val yield : unit -> unit

(* a tick's preemption due: the running process's 100ms over, another
 * ready (hzsched); the CPU given up so, without cooperative handing
 * over *)
val preempt_due : unit -> bool
val preempt : unit -> unit

(* what the scheduler does when nothing runs (Main: wait for an
 * interrupt, handle it) *)
val idle : (unit -> unit) ref

(* runs the processes, forever, the run queue's first each time (Plan 9's
 * order: a new process runs before its parent goes on); a dead one's
 * slot freed (Zombie: once off its kernel stack) *)
val scheduler : unit -> unit

(* a live process by its pid *)
val find : int -> proc option

(* [postnote p msg flag] (postnote): the note queued (NNOTE at most:
 * false when full; a kill's, without a handler for it, alone), p's
 * sleep interrupted, a rendezvous's given up (its value -1) *)
val postnote : proc -> string -> note_flag -> bool
