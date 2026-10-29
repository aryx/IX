(* Register allocation by coloring, in SSA form: each value a color (a
 * register, or a slot of the frame) that no value live with it has.
 * The values are colored in the dominator tree's order, each the
 * lowest color that no value live after its definition holds; for SSA
 * that order needs no more colors than the most values live at once
 * (its interference graph is chordal: Hack, Grund and Goos). Which
 * values get a register is chosen first (choose): by weight, each
 * while no point has more of them than there are registers, so that
 * the walk never runs out. A value may hint at others whose color it
 * would rather have (a phi's operands: the edge's move is then none).
 * mini-ml's and mini-cc's Alloc each say what their values are, what
 * must live in memory and what a use weighs.
 *
 * cs-history:
 * Gregory Chaitin's (IBM, 1981): a value a node, two values live at
 * once an edge, a register a color; coloring a graph is NP-complete,
 * so his was a heuristic. Sebastian Hack and others (2005, 2006) saw
 * that a program in SSA form has a chordal graph, which a greedy walk
 * in the right order colors optimally; what is left hard is the
 * phis' moves (coalescing).
 *
 * References: Sebastian Hack, Daniel Grund and Gerhard Goos, "Register
 * Allocation for Programs in SSA-Form" (Compiler Construction 2006); G.
 * Chaitin and others, "Register allocation via coloring" (Computer
 * Languages 6, 1981). *)

(* the points (each block's start, each instruction's end) from the
 * values live there: their number, and the points each value is live
 * at *)
val points : int Set_.t array -> (int, int Set_.t) Hashtbl.t -> int * (int, int list) Hashtbl.t

(* the values a register each: the heaviest first, (weight, value),
 * each taken while no point of it has nregs taken already *)
val choose :
  npoints:int -> at:(int, int list) Hashtbl.t -> nregs:int -> (int * int) list ->
  (int, unit) Hashtbl.t

(* the walk from the entry (the dominator tree's children): a block's
 * phis colored against its live values but them, then each candidate
 * of its body against the values of busy v (those live after it; a
 * dying operand's color free); a value's hints' colors tried first,
 * then the lowest below ncolors *)
val walk :
  children:int list array ->
  live_in:int Set_.t array ->
  phis:(int -> int list) ->
  body:(int -> int list) ->
  candidate:(int -> bool) ->
  busy:(int -> int Set_.t) ->
  hints:(int -> int list) ->
  int -> (int, int) Hashtbl.t
