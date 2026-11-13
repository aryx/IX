(* A kernel process (Plan 9's kproc) is a process of the kernel's own.
 * It runs a function in the kernel for ever, and it may sleep there as
 * a process in a system call does; it never goes to user mode. It is
 * for work that must wait, and so cannot be done by the clock: here,
 * Kusb's looking at the USB ports, which is mini-9pi's only kernel
 * process. The ones of its twin are counted only for the pids they
 * take (see Proc.kproc).
 *
 * Its record is a process's record with nothing of a program: it has
 * no memory, no descriptors, and an empty name space. Main's
 * process_start, where any new process first runs, finds the process's
 * slot in Proc.kernel_work and calls its function where another
 * process would go to user mode.
 *
 * others:
 * Every kernel has a few: 9pi has alarm, kgenrandom and kpager, and
 * Linux has kswapd and kworker (the names in brackets in a ps). They
 * are for work that belongs to no program and yet must be able to
 * sleep, which an interrupt's handler must not do. Here the clock's
 * tick does the work that never waits (Main's [devices]), and a kernel
 * process does the rest. *)

(* [start p name work] makes a new process, started from p (its root is
 * p's), and name is what ps shows. It does nothing when there is no
 * slot left. *)
val start : Types.proc -> string -> (unit -> unit) -> unit
