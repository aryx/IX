(* A C function's stack code as Datalog facts (docs/plans/plan_prolog.md,
 * stage 9): each instruction a point, who follows whom, and the
 * variables it reads and writes; for mini-datalog to run
 * languages/datalog/analyses/liveness.dl on. mini-cc -flow.
 *
 * The code is Lower's after Opti's passes but regs (a variable is read
 * and written whole by their forms, loadat and storeat), and the
 * variables are those regs considers (Opti.variables: an auto or a
 * parameter whose address is not taken).
 * A name is its function's: 'f:12' its instruction 12, 'f:x/-8' its
 * variable x at that offset.
 *   function(F). point(P, F). succ(P, Q). def(V, P). use(V, P). call(P). *)
val func : Ir.func -> string

(* What the compiler itself computed, to check the rules' answers
 * against (mini-cc -dflow): Opti's liveness, own_live_out(V, P). *)
val own : Ir.func -> string
