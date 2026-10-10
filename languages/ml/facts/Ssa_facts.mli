(* A function's SSA form as Datalog facts (docs/plans/plan_prolog.md,
 * stage 9): its blocks and who follows whom, each instruction as a
 * point of the program with the value it defines and those it uses,
 * the phis. mini-ml -flow, for mini-datalog to run
 * languages/datalog/analyses/liveness_ssa.dl and dominators.dl on.
 *
 * A name is its function's: 'f1_sum:b2' a block, 'f1_sum:v7' a value
 * and the instruction that makes it, 'f1_sum:t2' the end of block 2
 * (its jump, its return).
 *   function(F). block(B, F). entry(B). succ(B, S).
 *   first(B, P)   the block's first point (its end, if it has no instruction)
 *   next(P, Q)    in a block, the point after P
 *   last(B, T)    the block's end
 *   def(V, P). use(V, P).
 *   phi(V, B). phi_arg(V, Pred, X)   entered from Pred, V is X
 *   zero(V)       a slot never written: a value that needs no place
 * Nothing is computed here: what is live where is the rules' to find. *)
val func : Ssa.func -> string

(* What the compiler itself computed, as facts of other names, to check
 * the rules' answers against (mini-ml -dflow): Alloc's liveness
 * (own_live_in(V, B), own_live_out(V, B)) and Ssa_build's dominators
 * (own_idom(D, B)). *)
val own : Ssa.func -> string
