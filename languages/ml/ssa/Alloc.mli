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
 * below). Which values those are is chosen first: the most used, a use
 * in a loop 8 times one outside it, each while no point has more of
 * them live than there are registers; the others live in memory. A
 * constant lives nowhere: Emit makes it where it is read. No value in a register is live across a call, so
 * every register is the caller's to save, as simple's and C's are.
 * A double (Unbox) is a class of its own, colored the same way with
 * the floating-point registers: the collector never reads one, so it
 * goes to memory only across a call (clobbers), into a slot that is
 * not the value stack's (Dmem).
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
 * What is left hard, and not done here: the phis. A phi is a move on
 * each edge into its block unless its operands got its register (Emit
 * makes them one parallel copy), and choosing registers so that most
 * such moves vanish (coalescing) is NP-complete again. ocamlopt colors a graph, with
 * linear scan as an option (-linscan). Go's compiler runs what its
 * source calls a version of linear scan, a greedy walk of the
 * function as one long block; LLVM's default allocator, Greedy,
 * took linear scan's place in LLVM 3.0 (2011).
 *
 * References: Sebastian Hack, Daniel Grund and Gerhard Goos,
 * "Register Allocation for Programs in SSA-Form" (Compiler
 * Construction 2006); G. Chaitin and others, "Register allocation
 * via coloring" (Computer Languages 6, 1981); M. Poletto and V.
 * Sarkar, "Linear scan register allocation" (ACM TOPLAS 21(5),
 * 1999). *)

(* a double's slot, Dmem, is not the value stack's but one of its own,
 * which the collector does not scan (Emit: on the machine stack) *)
type loc = Reg of int | Mem of int | Nil | Dmem of int

(* two values in memory whose lives do not meet share a slot (false:
 * a slot each; mini-ml -own-slots) *)
val share_slots : bool ref

(* which values get a register: by their weight over the points they
 * are live at (false: their weight alone, mini-ml -by-uses) *)
val by_density : bool ref

(* an instruction after which the collector may have run (an allocation,
 * a call) *)
val safepoint : Ssa.ins -> bool

(* nregs registers for the words and nfregs for the doubles (Unbox),
 * each numbered from 0; memory's slots from base; the frame's slots
 * then, and the doubles' slots *)
val alloc : Ssa.func -> nregs:int -> nfregs:int -> base:int -> (Ssa.value -> loc) * int * int

(* the liveness alone: for each block, the values live at its start
 * and at its end (mini-ml -dflow prints it, for an analysis written
 * elsewhere to be checked against: languages/ml/facts/) *)
val liveness : Ssa.func -> int Set_.t array * int Set_.t array
