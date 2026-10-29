(* SSA from simple's stack code (plan_cc_ssa.md, step 1), after Opti's
 * forms (places, imm, branch, drops; not regs, which this replaces):
 * the blocks cut at the labels and the jumps, then Braun et al.'s
 * construction, as mini-ml's Ssa_build. Two kinds of variable: a C
 * variable a register may hold (Opti.variables, its address never
 * taken; and one read or written as another integer of its size, a
 * value as a uvalue, a conversion there), read by a LoadAt and
 * written by a StoreAt or a PutAt; and a slot of the stack at a
 * block's edge (the value of c ? a : b at its label). Each block is
 * filled in order, a variable's current value looked up in the block,
 * else asked of its predecessors, a phi placed where they are
 * several; a block is sealed when all its predecessors are filled,
 * and a phi made before that gets its operands then. Phis whose
 * operands are one value are taken out after (simplify), and a pure
 * value of one operand (q + 4) is moved down its block past the
 * operand's last use (sink: Ssa_gen's post-indexed accesses).
 *
 * What stays memory is the stack code's: a global, a variable whose
 * address is taken, a structure; their loads and stores are kept in
 * the order of the text, each block's body run as it is written. A
 * parameter is a Param at the entry, the value in its slot once the
 * prologue stored R0; an auto read before any write an Undef.
 *
 * The check (every use dominated by its definition, a phi's operands
 * its block's predecessors) runs on every function built.
 *
 * References: Matthias Braun, Sebastian Buchwald, Sebastian Hack,
 * Roland Leissa, Christoph Mallon and Andreas Zwinkau, "Simple and
 * Efficient Construction of Static Single Assignment Form" (Compiler
 * Construction 2013); mini-ml's Ssa_build, the same construction on
 * ML's stack machine. *)

(* built, simplified, checked *)
val func : Ir.func -> Ssa.func

(* the immediate dominator of each block, the entry its own *)
val dominators : Ssa.func -> int array

val successors_of : Ssa.block -> int list

(* the values an instruction reads, and a block's end *)
val operands : Ssa.ins -> Ssa.value list
val term_uses : Ssa.term -> Ssa.value list

(* mini-cc -simple -O -dssa *)
val show : Ssa.func -> string
