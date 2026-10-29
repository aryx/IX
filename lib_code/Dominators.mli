(* The dominator tree of a control-flow graph, and its loops: a block d
 * dominates b when every path from the entry to b passes through d;
 * the immediate dominator is the closest such d. A graph is its
 * blocks 0 to n - 1, block 0 the entry, given by each block's
 * successors and predecessors, as a compiler's SSA form (mini-ml's and
 * mini-cc's ssa/) or an analysis' flow graph has them.
 *
 * What it serves: SSA's check, a definition dominating its uses; the
 * coloring's order (Coloring), the tree walked from the entry; a
 * loop's blocks, an edge back to a block that dominates its source (a
 * natural loop), for the weight of a use inside one.
 *
 *     b0 -> b1 -> b2 -> b1        idom: b1's b0, b2's b1, b3's b1
 *            \-> b3               b2 -> b1 an edge back: the loop
 *                                 {b1, b2}, depth 1
 *
 * cs-history:
 * Dominators are Reese Prosser's (1959), for the flow diagrams of
 * programs; Thomas Lengauer and Robert Tarjan's algorithm (1979) is
 * almost linear, and the one compilers had for twenty years. The one
 * here, Keith Cooper, Timothy Harvey and Ken Kennedy's (2001), is a
 * dataflow over the reverse postorder, the predecessors' dominators
 * intersected by walking up the tree: a few lines, and on the graphs
 * of real functions as fast.
 *
 * References: K. Cooper, T. Harvey and K. Kennedy, "A Simple, Fast
 * Dominance Algorithm" (Software Practice and Experience, 2001);
 * the Dragon book's natural loops (Aho, Lam, Sethi and Ullman, 9.6). *)

(* each block's immediate dominator, the entry its own; -1 for a block
 * the entry does not reach *)
val idoms : succs:(int -> int list) -> preds:(int -> int list) -> int -> int array

(* a dominates b, by the tree *)
val dominates : int array -> int -> int -> bool

(* each block's children in the tree (the last found first) *)
val children : int array -> int list array

(* how many loops each block is in: for each edge back to a block h
 * that dominates its source, the blocks that reach the source without
 * passing h (h's natural loop), one more each *)
val loop_depths : succs:(int -> int list) -> preds:(int -> int list) -> int array -> int array
