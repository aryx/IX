(* The ssa back end's code (variants/ssa.md, phase 3): Ssa's form into
 * Plan 9's assembly, for arm and arm64, with simple's ABI (the closure
 * in R0, the arguments in R1.., the result in R0; the value stack's top
 * in R10 or R26, raised by the frame; C called with ml_vsp set, its
 * arguments R0 then w*(i+1)(SP); a try as ml_try's record, ml_raise
 * back to it), so that code by -ssa calls, and is called by, simple's.
 * An operation is simple's sequence of instructions for it, operand
 * for operand. Phase 3a: every value in its slot of the value stack,
 * which the prologue zeroes, as simple's; phis copied through staging
 * slots, on an edge of their own when the predecessor branches. *)

(* a function without a value in memory has no frame on the value
 * stack, and one that calls nothing with BL leaves the machine stack
 * and its link alone (false: every function both, as simple's) *)
val small_frames : bool ref

(* a function's SSA form as compiled: built (Ssa_build), its floats
 * unboxed (Unbox), its integers untagged (Untag); mini-ml -dssa's *)
val ssa : Asm.arch -> Ir.func -> Ssa.func

(* a unit's functions; the data are simple's Gen's *)
val unit_ : Asm.arch -> Ir.unit_ -> string
