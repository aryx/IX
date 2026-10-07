(* mini-singularity: the kernel's functions a process may call, numbered
 * (decision 3 of plan_system_singularity.md). A call is a number and
 * integers; what an integer points at is copied (cross.c: no value of
 * one heap is seen by the other's collector). A process's lib/sip.c
 * says the same numbers. *)

(* the process ends: its status *)
val exit : int
(* the debug line: bytes' address, their number; the number written *)
val debug : int

(* the call being served (registered as "abi": cross.c calls it); -1 for
 * a number that is no function *)
val call : unit -> int
