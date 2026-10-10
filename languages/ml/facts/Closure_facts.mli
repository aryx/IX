(* An ML unit as Datalog facts (docs/plans/plan_prolog.md, stage 10):
 * which function may be the value of which variable, and so which
 * functions a call may reach (0-CFA: every call of a function seen
 * together, a function's parameter one variable). mini-ml -facts.
 *
 * The facts are those of the author's pointer analysis of C
 * (languages/datalog/analyses/pointer.dl), whose rules then run
 * unchanged: a function written (fun, function, let f x = ...) is a
 * place, a variable points to the functions it may be, and every call
 * is a call through a pointer:
 *   assign_address(V, F)        V is the function F
 *   assign(V, W)                V is W
 *   parameter(F, 1, P). return(F, R)
 *   call_indirect(I, V). argument(I, 1, A). call_ret(I, R)
 *   assign_store_field(_, Fld, V). assign_load_field(V, _, Fld)
 * A function takes one argument: f x y is two calls, the second of
 * what the first returns, and let f x y = ... two functions, 'M.f'
 * and 'M.f''. What a block holds is by its field's name, whatever the
 * block (the rules' "field-based"): 'fld:contents' a record's field,
 * 'con:Some.0' a constructor's argument, 'tuple:2.0' a pair's first.
 * An external is a function 'prim:name'. A C function's arguments go
 * to one place for all of them, 'ext', and its result comes from it;
 * an array's elements and what a handler catches are there too. Those
 * the compiler writes in place move nothing (x + y), or what they are
 * known to: a ref's content ('fld:contents'), a pair's halves.
 * And, for the reports (analyses/calls.dl):
 *   closure(F, Unit, Line)      each function written
 *   inner(F2, F)                F2 is F's next argument's function (f' of f)
 *   in_function(I, F)           the call I is in F's body ('M:init': the toplevel's)
 *   init(F)                     a unit's toplevel, 'M:init': where a program starts
 * A name is its unit's ('Prolog:x/12' a variable, 'Prolog.deref' a
 * toplevel value, its symbol), so that the facts of a program's units
 * are one program's when put together.
 *
 * The question, on three lines of a unit Cf:
 *
 *     let apply f x = f x      which function does f x call?
 *     let inc n = n + 1
 *     let r = apply inc 1
 *
 * Nothing in apply says. The facts say that Cf.apply's parameter
 * flows to the variable f (assign), that the toplevel's call gives
 * it Cf.inc (argument), and that f x is a call through f
 * (call_indirect); the rules follow the functions through the
 * assignments until nothing new is found, and answer Cf.inc. It is
 * what Lower would need to make f x a direct call, and what says
 * which functions of a program nothing can call.
 *
 * cs-history:
 * The problem is the price of functions as values: in Fortran a call
 * names what it calls, in ML or Scheme most calls are of a variable,
 * and a compiler that wants to inline, or to know what a call may
 * change, must first find the functions that reach it. Olin Shivers
 * called it control-flow analysis (1988) and gave the family its
 * names: 0-CFA is the member that keeps one answer a variable,
 * whatever the call that led there; k-CFA tells apart the last k
 * calls, and costs accordingly.
 *
 * reframe:
 * A function passed around is a pointer passed around: Shivers's
 * question about Scheme is Lars Andersen's about C (1994), which
 * variables may hold the address of which objects, and one set of
 * rules answers both; that is why the facts above are a C
 * analysis's and nothing was written for ML but this module. That
 * such an analysis is a few lines of Datalog, a relation a fact
 * and the fixpoint the engine's work, was shown at scale by John
 * Whaley and Monica Lam (2004), whose rules for Java the author's
 * pointer.dl follows.
 *
 * References: Olin Shivers, "Control flow analysis in Scheme" (PLDI
 * 1988); Lars Ole Andersen, "Program Analysis and Specialization for
 * the C Programming Language" (his thesis, Copenhagen, 1994), chapter
 * 4; John Whaley and Monica Lam, "Cloning-based context-sensitive
 * pointer alias analysis using binary decision diagrams" (PLDI
 * 2004); mini-cc's Facts.mli, the same relations from C. *)
val unit_ : string -> Scope.item list -> string
