(* The dominator tree of a control-flow graph, and its loops: a block d
 * dominates b when every path from the entry to b passes through d;
 * the immediate dominator is the closest such d. A graph has the
 * blocks 0 to n - 1, with block 0 as the entry. It is given by each
 * block's successors and predecessors, as a compiler's SSA form
 * (mini-ml's and mini-cc's ssa/) or an analysis's flow graph has them.
 *
 * The module serves three uses:
 * - SSA's check, that a definition dominates its uses;
 * - the order of the coloring (Coloring), which walks the tree from
 *   the entry;
 * - a loop's blocks, for the weight of a use inside the loop. A loop
 *   is found by an edge back to a block that dominates the edge's
 *   source (a natural loop).
 *
 *     b0 -> b1 -> b2 -> b1        idom: b0 for b1, b1 for b2 and b3
 *            \-> b3               b2 -> b1 is an edge back, so the
 *                                 loop is {b1, b2}, of depth 1
 *
 * cs-history:
 * Dominators come from Reese Prosser (1959), for the flow diagrams of
 * programs. Thomas Lengauer and Robert Tarjan's algorithm (1979) is
 * almost linear, and it is the one compilers used for twenty years.
 * The one here, by Keith Cooper, Timothy Harvey and Ken Kennedy
 * (2001), is a dataflow over the reverse postorder, which intersects
 * the predecessors' dominators by walking up the tree. It is a few
 * lines, and just as fast on the graphs of real functions.
 *
 * References: K. Cooper, T. Harvey and K. Kennedy, "A Simple, Fast
 * Dominance Algorithm" (Software Practice and Experience, 2001);
 * the Dragon book's natural loops (Aho, Lam, Sethi and Ullman, 9.6). *)

(* each block's immediate dominator (the entry is its own), or -1 for a
 * block that the entry does not reach *)
val idoms : succs:(int -> int list) -> preds:(int -> int list) -> int -> int array

(* [dominates idom a b] says whether a dominates b, by the tree *)
val dominates : int array -> int -> int -> bool

(* each block's children in the tree (the last found first) *)
val children : int array -> int list array

(* how many loops each block is in. For each edge back to a block h
 * that dominates the edge's source, the blocks that reach the source
 * without passing through h (h's natural loop) each count one more
 * loop. *)
val loop_depths : succs:(int -> int list) -> preds:(int -> int list) -> int array -> int array
