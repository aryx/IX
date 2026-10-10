(* The ssa back end (plan: variants/ssa.md), phase 1: a function of
 * Lower's stack machine to SSA form (Ssa's types), printed by mini-ml
 * -dssa and checked.
 *
 * The blocks are the stack code's runs between labels and jumps (a
 * try's handler a successor of the block its try ends), those the
 * entry does not reach dropped, as Gen drops dead code. The
 * construction is Braun and others' (2013, below): a frame's slot,
 * and a position of the stack at a
 * block's edge, are variables; a stack entry inside a block is a
 * value; a block is sealed when its predecessors are all filled, and
 * the phis it needed then get their operands; the trivial ones (one
 * value, and themselves) go at the end. No dominance frontiers.
 *
 * A function with a handler keeps its slots in memory (slot, setslot):
 * its handler would need each slot's value at whichever point raised,
 * which is for later. The check: every use dominated by its
 * definition (Cooper, Harvey and Kennedy's dominators), a phi's
 * operands its block's predecessors.
 *
 * Ssa's header has a function before and after. In it, reading slot
 * 4 in b3 asks b3 for the slot's value; b3 has none of its own, has
 * two predecessors, so makes a phi and asks each: b1 wrote v5, b2
 * did not and asks b0, where the slot is the parameter v3. A block
 * with one predecessor asks it and makes no phi; a phi whose
 * operands turn out to be one value is that value. A loop is why
 * blocks are sealed: its head is read before the jump back to it
 * is known, so its phi waits for its last operand.
 *
 * others:
 * The classical construction (Cytron and others, 1991) goes the
 * other way, from the definitions: compute the dominator tree, from
 * it each block's dominance frontier, the blocks where a definition
 * stops being the only one that reaches, put a phi there for each
 * variable written, then rename in one walk of the tree. It gives
 * the minimal form at once and is what LLVM's mem2reg does; it
 * needs the whole graph and the dominators first. Braun's needs
 * neither, works as the code is read, and is what a compiler that
 * makes SSA straight from a tree wants (libFirm, its authors'). Here the
 * dominators are computed anyway, but only to check the result.
 *
 * terminology:
 * A block d dominates b when every path from the entry to b goes
 * through d; b's immediate dominator is the closest one, and those
 * make a tree. SSA's rule is said with it: a definition dominates
 * each of its uses. The fast algorithm is Lengauer and Tarjan's
 * (1979); Cooper, Harvey and Kennedy's (2001), here, is a dataflow
 * iteration over the blocks in reverse postorder, a page of code,
 * and faster in practice on the graphs compilers meet.
 *
 * References: M. Braun, S. Buchwald, S. Hack, R. Leissa, C. Mallon
 * and A. Zwinkau, "Simple and Efficient Construction of Static
 * Single Assignment Form" (Compiler Construction 2013), whose
 * algorithms 1 to 4 this follows; K. Cooper, T. Harvey and K.
 * Kennedy, "A Simple, Fast Dominance Algorithm" (2001); T. Lengauer
 * and R. Tarjan, "A fast algorithm for finding dominators in a
 * flowgraph" (ACM TOPLAS 1(1), 1979). *)

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
