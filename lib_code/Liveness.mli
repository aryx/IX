(* Liveness in SSA form, whatever the instructions: a value is live at
 * a point when a path from it reaches a use without passing its
 * definition. A backward dataflow over the blocks, to its fixpoint (the
 * Dragon book's), with SSA's rule for the phis: a phi's operand is
 * live at the end of the predecessor it comes from, not at its block's
 * start, and the phi itself is defined at that start. The values are
 * numbers, the blocks 0 to n - 1; what an instruction reads is the
 * caller's to say, the values that need no place (a constant made
 * where it is read) left out.
 *
 * Met in the tree three more times: mini-cc's Opti (regs) over a C
 * function's variables, its Peep over the machine's registers, and as
 * Datalog rules (languages/datalog/analyses/liveness.dl, liveness_ssa.dl).
 *
 * Reference: Aho, Lam, Sethi and Ullman, Compilers (the Dragon book),
 * 9.2.5, live-variable analysis. *)

(* the values live at each block's start and at its end: its
 * successors; its phis; the operands its phis read from a predecessor
 * (phi_uses s p); what its end reads; its body, in order; what each
 * value's instruction reads *)
val ssa :
  succs:(int -> int list) ->
  phis:(int -> int list) ->
  phi_uses:(int -> int -> int list) ->
  term_uses:(int -> int list) ->
  body:(int -> int list) ->
  uses:(int -> int list) ->
  int -> int Set_.t array * int Set_.t array

(* the values live after each instruction of a body, from the blocks'
 * ends (ssa's second array) *)
val after :
  term_uses:(int -> int list) ->
  body:(int -> int list) ->
  uses:(int -> int list) ->
  int Set_.t array -> int -> (int, int Set_.t) Hashtbl.t
