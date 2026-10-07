(* mini-singularity: the kernel's functions a process may call, numbered
 * (decision 3 of plan_system_singularity.md). A call is a number and
 * integers; what an integer points at is copied (cross.c: no value of
 * one heap is seen by the other's collector); what a process holds of
 * the kernel is a handle (Process). A process's lib/sip.c says the
 * same numbers.
 *   0 exit status            the process ends
 *   1 debug address bytes    the debug line; the bytes written
 *   2 yield                  the others run
 *   3 create address bytes   a process of the program of that name,
 *                            not started: its handle, or -1
 *   4 start handle           0, or -1
 *   5 join handle            waits for its end: its status, or -1 *)

(* the call being served (registered as "abi": cross.c calls it); -1 for
 * a number that is no function *)
val call : unit -> int
