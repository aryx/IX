(* TinyKernel's scheduler: round robin and preemptive, on one core or
 * several. Core 0 belongs to the kernel. It runs a process until the
 * process traps (a system call, a fault, or the timer's interrupt),
 * handles the trap, and then runs the same process again, unless its
 * time slice is used up or it cannot go on; in that case it moves to
 * the next process. The other cores only run processes, and they post
 * their traps to core 0 (plan_tiny_multicore.md). When no process can
 * run, the kernel waits for an interrupt: a key, the mouse, the
 * network or the timer.
 *
 *     schedule ──► next runnable process (Ready, or Waiting with its
 *        ▲          call now able to finish) ──k_run──► its trap
 *        └────────── trap handled: a call, a fault, a tick ◄──┘
 *
 * Interrupts are handled between two runs. The console's bytes are
 * read (^C kills the foreground process), the mouse's word is read,
 * the network's packets are given to KNetwork, and the timer's ticks
 * are counted.
 *
 * others:
 * xv6's scheduler is the same loop over a process table, but each
 * process has its own kernel stack that the scheduler switches to.
 * Here a process waiting in a call is a closure (see KProcs.mli), so
 * there is only one stack, the kernel's.
 *)

(* The loop. It never returns. *)
val schedule : unit -> 'a
