(* The arm64 machine, as 7c: its moves and conversions, its
 * instructions, and what Cgen asks of it. Its types (pointers are
 * vlongs, which the machine computes itself) are the front end's,
 * Machines.arm64. *)

(* for Regs *)
val backend : Regs.backend

(* for Cgen *)
val hooks : Cgen.hooks
