(* TinyKernel's scheduler: round robin, preemptive, on one core or
 * several. Core 0 is the kernel's: it runs a process until its trap
 * (a call, a fault, the timer's interrupt), handles the trap, and runs
 * the same process again unless its time is up or it cannot go on, then
 * the next one; the other cores run processes only, their traps posted
 * to core 0 (plan_tiny_multicore.md). With none to run, it waits for
 * an interrupt: a key, the mouse, the network, the timer.
 *
 *     schedule ──► the next that can run (Ready, or Waiting and its
 *        ▲          call now finished) ──k_run──► its trap
 *        └────────── the trap handled: a call, a fault, a tick ◄──┘
 *
 * The interrupts are handled between two runs: the console's bytes
 * (^C kills the foreground), the mouse's word, the network's packets
 * given to TinyKernelNetwork, the timer's ticks counted.
 *
 * others:
 * xv6's scheduler is the same loop over a process table, each process
 * a kernel stack it switches to; here a process waiting in a call is a
 * closure (TinyKernelProcs.mli), so there is one stack, the kernel's.
 *)

(* the loop, which never returns *)
val schedule : unit -> 'a
