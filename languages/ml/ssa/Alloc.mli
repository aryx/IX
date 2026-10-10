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
 * is chordal, that order colors optimally (Hack, Grund and Goos,
 * below); one that finds none
 * lives in memory. No value in a register is live across a call, so
 * every register is the caller's to save, as simple's and C's are.
 *
 * Liveness is the analysis met three times in the tree: here over
 * SSA's values, in mini-cc's Opti (regs) over a C function's
 * variables, in its Peep over the machine's registers; and once more
 * as nine Datalog rules (liveness_ssa.dl), which Ssa_facts gives the
 * facts for and [liveness] below the answers to compare.
 *
 * cs-history:
 * Register allocation as the coloring of a graph is Gregory Chaitin's
 * and his colleagues' at IBM (1981): a node a value, an edge between
 * two values alive at the same time, a color a register, and a node
 * that cannot be colored is spilled to memory and the graph made
 * again. Coloring a graph with k colors is NP-complete, so every
 * such allocator is a heuristic, and a slow one. Massimiliano
 * Poletto and Vivek Sarkar's linear scan (1999) gave up the graph
 * for one walk over the values sorted by where they start, for
 * compilers that run while the program waits. Then it was seen
 * (Hack and others, 2005 and 2006) that the graph of a program in
 * SSA form is of a kind, chordal, that a greedy walk in the right
 * order colors with the fewest colors.
 *
 * modern:
 * What is left hard, and not done here (phase 3c): the phis. A phi
 * is a move on each edge into its block unless its operands got its
 * register, and choosing registers so that most such moves vanish
 * (coalescing) is NP-complete again. ocamlopt colors a graph, with
 * linear scan as an option; Go's compiler and LLVM's default
 * allocator are neither, greedy walks with heuristics of their own.
 *
 * References: Sebastian Hack, Daniel Grund and Gerhard Goos,
 * "Register Allocation for Programs in SSA Form" (Compiler
 * Construction 2006); G. Chaitin and others, "Register allocation
 * via coloring" (Computer Languages 6, 1981); M. Poletto and V.
 * Sarkar, "Linear scan register allocation" (ACM TOPLAS 21(5),
 * 1999). *)

type loc = Reg of int | Mem of int | Nil

(* nregs registers, numbered from 0; memory's slots from base; the
 * frame's slots then *)
val alloc : Ssa.func -> nregs:int -> base:int -> (Ssa.value -> loc) * int

(* the liveness alone: for each block, the values live at its start
 * and at its end (mini-ml -dflow prints it, for an analysis written
 * elsewhere to be checked against: languages/ml/facts/) *)
val liveness : Ssa.func -> int Set_.t array * int Set_.t array
