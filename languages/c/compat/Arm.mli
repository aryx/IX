(* The arm machine, as 5c: its moves and conversions, its
 * instructions, and what Cgen asks of it. Its types (pointers are longs,
 * vlongs are structures and their operators calls to libc) are the
 * front end's, Machines.arm. *)

(* for Regs *)
val backend : Regs.backend

(* for Cgen *)
val hooks : Cgen.hooks
