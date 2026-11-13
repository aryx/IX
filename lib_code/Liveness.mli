(* Liveness in SSA form, for any kind of instructions. A value is live
 * at a point when a path from that point reaches a use without passing
 * through the value's definition. It is computed by a backward dataflow
 * over the blocks, up to its fixpoint (the Dragon book's), with SSA's
 * rule for the phis: a phi's operand is live at the end of the
 * predecessor it comes from, not at the start of the phi's block, and
 * the phi itself is defined at that start. The values are numbers, and
 * the blocks are 0 to n - 1. The caller says what an instruction reads,
 * leaving out the values that need no place (such as a constant made
 * where it is read).
 *
 * Liveness is met in the tree three more times: in mini-cc's Opti
 * (regs), over a C function's variables; in its Peep, over the
 * machine's registers; and as Datalog rules
 * (analyzers/datalog/liveness.dl, liveness_ssa.dl).
 *
 * Reference: Aho, Lam, Sethi and Ullman, Compilers (the Dragon book),
 * 9.2.5, live-variable analysis. *)

(* [ssa ...] returns the values live at each block's start and at its
 * end. A block is described by:
 * - [succs], its successors;
 * - [phis], its phis;
 * - [phi_uses s p], the operands that the phis of s read from the
 *   predecessor p;
 * - [term_uses], what its end reads;
 * - [body], its body, in order;
 * and [uses] gives what each value's instruction reads. *)
val ssa :
  succs:(int -> int list) ->
  phis:(int -> int list) ->
  phi_uses:(int -> int -> int list) ->
  term_uses:(int -> int list) ->
  body:(int -> int list) ->
  uses:(int -> int list) ->
  int -> int Set_.t array * int Set_.t array

(* the values live after each instruction of a body, computed from the
 * values live at the blocks' ends (ssa's second array) *)
val after :
  term_uses:(int -> int list) ->
  body:(int -> int list) ->
  uses:(int -> int list) ->
  int Set_.t array -> int -> (int, int Set_.t) Hashtbl.t
