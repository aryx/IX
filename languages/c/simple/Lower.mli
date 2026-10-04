(* A function's typed tree to a stack machine's code (the simple back
 * end whose contract is the behavior: plan_cc.md, decision 8).
 *
 * The machine is Ir's: its values, its operations, each taking its
 * operands from the top of the stack. The front end's trees are used as they are: no
 * addressability, no 5c's rewrites (acom): an expression is its
 * operands, then its operator; of a binary operator's operands the one
 * that needs more of the stack goes first (Ershov's number, then a
 * Swap), unless one calls, and a call's value is computed before the
 * address it is stored to (nothing is live across x = setjmp(b)). A condition is jumps (&&, ||, !,
 * ?:), a relation's value 1 or 0.
 *
 * Calls: the arguments that call are computed first, into temporaries,
 * so that the others are stored straight into the outgoing area (at
 * their offsets, Declare's Aarg1 and Aarg2, as 7c's), the first one
 * also in R0 when it is a word; a structure's result goes to a
 * temporary whose address is the hidden first argument. This is 5c's
 * and 7c's convention, so that what simple compiles calls libc, and is
 * called by it.
 *
 * The frame: Declare's autos, then the temporaries (the arguments'
 * values, the results' structures, a switch's value), freed after each
 * statement; Gen adds the stack's spills and the outgoing area. *)

val func : Tree.sym -> Tree.stmt -> Ir.func

(* an instruction, and a function, as mini-cc -dir prints them *)
val show_func : Ir.func -> string

(* the front end's hook (Check.xcom): on arm, a vlong's operations as
 * calls to libc (Com64), bottom up; on arm64 the tree as it is *)
val calls64 : Tree.expr -> Tree.expr
