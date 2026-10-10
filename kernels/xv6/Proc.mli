(* mini-xv6's processes (xv6's proc.c, less fork, exit and wait, which
 * need the files: Syscall.ml): the table, sleep and wakeup, the
 * scheduler.
 *
 * No locks. xv6 takes a lock around every change of a process's state
 * and hands it through the switch; this kernel runs on one core and is
 * never interrupted (IRQs arrive in user mode only: kernels/steps/step5), so a
 * check and the sleep after it cannot be separated by a wakeup: xv6's
 * lost-wakeup problem does not arise, and sleep needs no lock to
 * release.
 *
 * A process in the kernel is a stack of its own (a slot: Machine's)
 * and a state. It never runs another process: it goes back to the
 * scheduler, which has a stack too (the boot's, scheduler_slot), and
 * the scheduler picks the next:
 *
 *     sh, in read          the scheduler            cat, in write
 *     state <- Sleeping c
 *     sched  ------------> swtch returns
 *     (its frames kept     next Runnable slot:
 *      on its stack)       state <- Running
 *                          its table in TTBR0
 *                          swtch -----------------> returns from the
 *                                                   sched it had made
 *                                                   ...
 *                          swtch returns <--------- yield (a tick)
 *
 * So every switch is two, and a process always sleeps and wakes at
 * the same line, sched's call. A reader of a pipe with nothing in it
 * does  while empty do sleep (Pipe_readable p) done , and a writer
 * wakeup (Pipe_readable p) : wakeup makes Runnable every process
 * whose state is Sleeping on that same thing; each looks again at
 * what it waited for when it runs, which is why the sleep is in a
 * loop.
 *
 * The lost wakeup, which is not here. On two processors, or with
 * interrupts taken in the kernel, between the reader's test (empty)
 * and its sleep the writer may write and wake: nobody is asleep yet,
 * the wakeup does nothing, and the reader then sleeps for ever on a
 * pipe that has bytes. xv6's sleep takes the lock that guards the
 * condition and releases it only once the process is marked asleep.
 *
 * design:
 * What a process sleeps on (Types.chan). In Unix and xv6 a channel
 * is any address, by convention that of the thing waited for (the
 * pipe's struct, the ticks' variable), compared as a number: nothing
 * says what waits for what. Here it is a variant that names it, and
 * the state carries it (Sleeping of chan): a process cannot be
 * asleep without a channel, nor have one when it runs.
 *
 * cs-history:
 * sleep and wakeup on a channel, and the switch through a scheduler
 * that is no process, are the sixth edition's (slp.c). Its switch is
 * where Dennis Ritchie's comment is, "You are not expected to
 * understand this": the code saved and restored the registers of two
 * different calls, and depended on how the PDP-11's compiler laid
 * out a frame. The seventh edition did it again another way; xv6's
 * swtch, a few lines of assembly that exchange the registers a
 * function must keep, is what Machine.swtch is.
 *
 * others:
 * Round robin over a table of 64 is xv6's whole policy. Unix gave
 * each process a priority recomputed from the processor time it had
 * used, so that who types is served before who computes; Linux has
 * had several schedulers since (the completely fair one from 2007).
 * mini-singularity's processes are switched by the same C slots,
 * with no table to change.
 *
 * References: the xv6 book's chapter "Scheduling" (the switch, sleep
 * and wakeup, the lost wakeup worked out with its locks); Lions'
 * commentary, on slp.c; Dennis Ritchie, "Odd Comments and Strange
 * Doings in Unix" (his page at Bell Labs, on the comment; from
 * memory). xv6's proc.c and swtch.S. *)

(* NPROC; the slot of the scheduler's context, after the processes' *)
val nproc : int
val scheduler_slot : int

(* the processes, by slot (a slot is a kernel stack and a trap frame,
 * machine.c's) *)
val procs : Types.proc option array
val nextpid : int ref

(* the clock, 100 ticks a second (xv6's ticks) *)
val ticks : int ref

(* the running process (not to be called from the scheduler) *)
val myproc : unit -> Types.proc

(* the processes, in slot order; those with a pid *)
val all : unit -> Types.proc list
val find : int -> Types.proc list

(* back to the scheduler; the running process asleep on a channel; those
 * asleep on it made runnable; the CPU given up *)
val sched : unit -> unit
val sleep : Types.chan -> unit
val wakeup : Types.chan -> unit
val yield : unit -> unit

(* xv6's kill: 0, or -1 (no such pid) *)
val kill : int -> int

val free_slot : unit -> int option

(* what the scheduler does when nothing can run: set by Main (wait for
 * an interrupt, handle it) *)
val idle : (unit -> unit) ref

(* round robin over the slots, forever (xv6's scheduler) *)
val scheduler : unit -> 'a
