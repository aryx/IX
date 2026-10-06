(* A process of the kernel's own (Plan 9's kproc): it runs a function
 * in the kernel, for ever, and may sleep there as a process in a
 * system call does; it never goes to user mode. For what must wait and
 * so cannot be the clock's: Kusb's look at the USB ports. mini-9pi had
 * none (its twin's are counted for their pids only: Proc.kproc). *)

(* [start p name work]: a new process (name is what ps shows), started
 * from p (its root is p's); nothing when there is no slot left *)
val start : Types.proc -> string -> (unit -> unit) -> unit
