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
 * are one program's when put together. *)
val unit_ : string -> Scope.item list -> string
