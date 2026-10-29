(* A C function's assembly from its SSA form (plan_cc_ssa.md, step 3),
 * its values where Alloc put them: an instruction's operands read
 * from their registers, or loaded into a scratch one (R0 and Gen's
 * tmp, R8 on arm, R16 on arm64; F0 and F7, F16) from their slot, or
 * made there (a constant); its result written to its register, or to
 * the scratch and stored. The instructions are Gen's, by type, so an
 * integer's result is extended as Gen's are. A phi is a parallel
 * copy on each edge into its block, in the predecessor when the edge
 * is its jump or its fall, in moves of their own when it is a
 * branch's taken target; a block's jump to the next is no jump. At a
 * call, the registers live across it are stored to their slots and
 * loaded after (Alloc's saves), a parameter's from its own. A load or
 * a store through q followed by q + k in q's register is one
 * post-indexed access (MOVW.P), which the sink of Ssa_build and the
 * phi's register of Alloc make the common case of *q++.
 *
 * Integer registers: arm's R1-R7, arm64's R1-R15 and R19-R25; floats
 * F1-F6, and F1-F15 and F17-F23. The frame: the locals, the slots
 * (Alloc's) below them where Gen keeps its spills, the outgoing
 * arguments. *)

val func : Ssa.func -> unit
