(* A process of the kernel's own (Plan 9's kproc): it runs a function
 * in the kernel, for ever, and may sleep there as a process in a
 * system call does; it never goes to user mode. For what must wait and
 * so cannot be the clock's: Kusb's look at the USB ports. mini-9pi had
 * none (its twin's are counted for their pids only: Proc.kproc).
 *
 * Its record is a process's with nothing of a program: no memory, no
 * descriptors, an empty name space. Main's process_start, where any
 * new process first runs, finds its slot in Proc.kernel_work and
 * calls its function where another would go to user mode.
 *
 * others:
 * Every kernel has a few: 9pi's alarm, kgenrandom and kpager, Linux's
 * kswapd and kworker in a ps (the names in brackets). They are for
 * work that belongs to no program and yet must be able to sleep,
 * which an interrupt's handler must not: here the clock's tick does
 * what never waits (Main's [devices]), and this is for the rest. *)

(* [start p name work]: a new process (name is what ps shows), started
 * from p (its root is p's); nothing when there is no slot left *)
val start : Types.proc -> string -> (unit -> unit) -> unit
