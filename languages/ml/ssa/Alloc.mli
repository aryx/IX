(* Where each SSA value lives (variants/ssa.md, phase 3b): a register,
 * a slot of the value stack, or nowhere (the constant 0, or a value no
 * one reads).
 *
 * Liveness first, a backward dataflow over the blocks to its fixpoint,
 * a phi's operand live at its predecessor's end and its definition at
 * its block's start. Then memory for the values the collector must
 * see: live across a safepoint (an allocation, whose fields are read
 * after it; a call of ML or of C; a polymorphic comparison, which may
 * call compare), live into a handler (a raise restores no register),
 * and the parameters (the prologue's slots). The others are colored in
 * the dominator tree's order, each the lowest register that no value
 * live after its definition holds: for SSA, whose interference graph
 * is chordal, that order colors optimally (Sebastian Hack, "Register
 * Allocation for Programs in SSA Form", 2006); one that finds none
 * lives in memory. No value in a register is live across a call, so
 * every register is the caller's to save, as simple's and C's are. *)

type loc = Reg of int | Mem of int | Nil

(* nregs registers, numbered from 0; memory's slots from base; the
 * frame's slots then *)
val alloc : Ssa.func -> nregs:int -> base:int -> (Ssa.value -> loc) * int

(* the liveness alone: for each block, the values live at its start
 * and at its end (mini-ml -dflow prints it, for an analysis written
 * elsewhere to be checked against: languages/ml/facts/) *)
val liveness : Ssa.func -> int Set_.t array * int Set_.t array
