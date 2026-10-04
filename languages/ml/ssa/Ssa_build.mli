(* The ssa back end (plan: variants/ssa.md), phase 1: a function of
 * Lower's stack machine to SSA form (Ssa's types), printed by mini-ml
 * -dssa and checked.
 *
 * The blocks are the stack code's runs between labels and jumps (a
 * try's handler a successor of the block its try ends), those the
 * entry does not reach dropped, as Gen drops dead code. The
 * construction is Braun, Buchwald, Hack, Leissa, Mallon and Zwinkau's
 * ("Simple and Efficient Construction of Static Single Assignment
 * Form", CC 2013): a frame's slot, and a position of the stack at a
 * block's edge, are variables; a stack entry inside a block is a
 * value; a block is sealed when its predecessors are all filled, and
 * the phis it needed then get their operands; the trivial ones (one
 * value, and themselves) go at the end. No dominance frontiers.
 *
 * A function with a handler keeps its slots in memory (slot, setslot):
 * its handler would need each slot's value at whichever point raised,
 * which is for later. The check: every use dominated by its
 * definition (Cooper, Harvey and Kennedy's dominators), a phi's
 * operands its block's predecessors. *)

(* built, the trivial phis out, checked (Failure if not) *)
val func : Ir.func -> Ssa.func

(* -dssa *)
val show : Ssa.func -> string

(* an instruction's operands; each block's immediate dominator (the
 * entry its own) *)
val operands : Ssa.ins -> Ssa.value list
val dominators : Ssa.func -> int array

(* mini-ml -ssa, phase 2: each function through SSA and back to the
 * stack machine, every value in its own slot, for simple's Gen *)
val unit_ : Ir.unit_ -> Ir.unit_
