(* A function's SSA form as Datalog facts (docs/plans/plan_prolog.md,
 * stage 9): its blocks and who follows whom, each instruction as a
 * point of the program with the value it defines and those it uses,
 * the phis. mini-analyze -flow, for mini-datalog to run
 * analyzers/datalog/liveness_ssa.dl and dominators.dl on.
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
 *   site(P, K)    the call at P (a value, or a block's tail call) is the
 *                 application K, unit:start-stop of its function's span,
 *                 as Closure_facts' site_key names it (when Lower.sites)
 * Nothing is computed here: what is live where is the rules' to find.
 * prefix: before each relation's name (-bugs' ssa_, whose function and
 * entry are another's there); unit_name: the keys' unit.
 *
 * design:
 * What SSA gives an analysis that ignores the order. points_to/ is
 * flow-insensitive: a variable has one set of objects for its whole
 * function, whatever was written in it before or after. In C that
 * loses much: p = malloc(n); free(p); p = &x is one p, pointing to
 * both. SSA renames each write, p1 and p2, and a flow-insensitive
 * analysis of the names is then as sharp as a flow-sensitive one for
 * them: the order was in which write a read sees, and the names now
 * say it. ML's let-variables need no renaming, being written once
 * (Appel's "SSA is functional programming", Ssa.mli): Closure_facts'
 * variables are SSA's already, and points_to/ is flow-sensitive for
 * them for free. What stays insensitive is what is written more than
 * once: a ref's contents, a field, an array's element (the heap: its
 * updates would need a flow-sensitive analysis's strong ones).
 * The names do not give the order of the effects, a call before
 * another, nor the paths: those are the blocks. next and succ are the
 * paths; a definition dominates each of its uses, so a value's flow
 * is an order too; X dominates N when no path from the entry to N
 * avoids X (dominators.dl), and a path from A that avoids R is the
 * question "R on every path after A?" (bugs/pairs.dl's held, R a
 * close, A an open, a raise on such a path a leak). A phi says where
 * paths meet and which value came by which edge; what a branch tested
 * it does not say, and a property true on one path only (a close
 * `when o != c`, 62d811be) needs the conditions too: path-sensitive.
 * The two kinds of facts meet at the calls: an SSA call is named by
 * its application (site), as Closure_facts names its sites
 * (site_key), so a rule asks points-to what a call takes and the
 * blocks when. The SSA is mini-ml's own, the compiler's, lowered
 * (closures called by their code, a curried call checked at run
 * time): one graph for the compiler and the analyses, no second.
 *
 * References: Rebecca Hasti, Susan Horwitz, "Using static single
 * assignment form to improve flow-insensitive pointer analysis" (PLDI
 * 1998); Ben Hardekopf, Calvin Lin, "Flow-sensitive pointer analysis
 * for millions of lines of code" (CGO 2011), the semi-sparse one;
 * Ondrej Lhotak, Kwok-Chiang Andrew Chung, "Points-to analysis with
 * efficient strong updates" (POPL 2011). *)
val func : ?prefix:string -> ?unit_name:string -> Ssa.func -> string

(* a call's application as a key: Unit:start-stop *)
val key : string -> int * int -> string

(* What the compiler itself computed, as facts of other names, to check
 * the rules' answers against (mini-analyze -dflow): Alloc's liveness
 * (own_live_in(V, B), own_live_out(V, B)) and Ssa_build's dominators
 * (own_idom(D, B)). *)
val own : Ssa.func -> string
