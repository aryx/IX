(* What a process of mini-singularity asks of the kernel beyond what
 * the standard library does for it (print_string: the debug line;
 * exit: its end): the kernel's ABI (Abi), by lib/sip.c. *)

(* another process, held by this one: a handle, which means something
 * to this process only *)
type process

(* the other processes run; back when the kernel's turn comes again *)
val yield : unit -> unit

(* a process of the program of that name, not started: None if there is
 * no such program, or one of it runs already *)
val create : string -> process option
val start : process -> unit
(* waits for its end: its status. The handle is no longer one *)
val join : process -> int
