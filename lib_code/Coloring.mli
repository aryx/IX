(* Register allocation by coloring, in SSA form. Each value gets a color
 * (a register, or a slot of the frame) that no value live at the same
 * time has. The values are colored in the order of the dominator tree,
 * each with the lowest color that no value live after its definition
 * holds. For SSA, that order needs no more colors than the largest
 * number of values live at once, because its interference graph is
 * chordal (Hack, Grund and Goos). Which values get a register is
 * chosen first (choose), by weight: each value is taken while no point
 * has more of them than there are registers, so that the walk never
 * runs out. A value may hint at other values whose color it would
 * rather have (for a phi, its operands: the move on the edge is then
 * not needed). mini-ml's and mini-cc's Alloc each say what their
 * values are, what must live in memory and what a use weighs.
 *
 * cs-history:
 * The method is Gregory Chaitin's (IBM, 1981): a value is a node, two
 * values live at once are joined by an edge, and a register is a
 * color. Coloring a graph is NP-complete, so his method was a
 * heuristic. Sebastian Hack and others (2005, 2006) saw that a program
 * in SSA form has a chordal graph, which a greedy walk in the right
 * order colors optimally. What remains hard is the phis' moves
 * (coalescing).
 *
 * References: Sebastian Hack, Daniel Grund and Gerhard Goos, "Register
 * Allocation for Programs in SSA-Form" (Compiler Construction 2006); G.
 * Chaitin and others, "Register allocation via coloring" (Computer
 * Languages 6, 1981). *)

(* [points live_in after] numbers the points (each block's start, each
 * instruction's end) from the values live there. It returns how many
 * points there are, and the points each value is live at. *)
val points : int Set_.t array -> (int, int Set_.t) Hashtbl.t -> int * (int, int list) Hashtbl.t

(* [choose ~npoints ~at ~nregs wanted] picks the values that get a
 * register each, from (weight, value) pairs. The heaviest come first,
 * and each is taken while no point where it is live already has nregs
 * values taken. *)
val choose :
  npoints:int -> at:(int, int list) Hashtbl.t -> nregs:int -> (int * int) list ->
  (int, unit) Hashtbl.t

(* [walk ... ncolors] walks from the entry, down the dominator tree
 * ([children]). In each block, the phis are colored against the
 * block's live values other than the phis. Then each candidate of the
 * block's body is colored against the values of [busy v] (those live
 * after it, so that the color of an operand that dies there is free).
 * For a value, the colors of its hints are tried first, then the
 * lowest color below ncolors. *)
val walk :
  children:int list array ->
  live_in:int Set_.t array ->
  phis:(int -> int list) ->
  body:(int -> int list) ->
  candidate:(int -> bool) ->
  busy:(int -> int Set_.t) ->
  hints:(int -> int list) ->
  int -> (int, int) Hashtbl.t
