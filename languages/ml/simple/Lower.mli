(* From Scope's tree to a stack machine (plan_ml.md, decision 6: TinyC's
 * design, and tiny-ml's, whose code this generalizes): expressions push
 * their value, an operation pops its operands, statements are labels
 * and jumps. What was Lambda, Match and Closure in the plan is here,
 * each a part:
 *
 * - {b patterns} a sequence of tests, each jumping to the next clause
 *   (the tutorial's section 7): the clauses in order;
 * - {b closures}: a function is code with its closure in slot 0 and its
 *   parameters after, its free variables fields of the closure; a
 *   function without free variables is a static block; a call of a
 *   known function (a let or a toplevel of this unit) with all its
 *   arguments is a direct call, any other one argument at a time
 *   through the closure's first field (curry functions, eval/apply),
 *   unless its closure says it takes them all (calls_whole);
 * - {b primitives}: an external "%name" an instruction, another a call
 *   of the runtime's C.
 *
 * The machine itself is Ir's. *)

(* a unit (its module's name) and its init function M.init *)
val unit_ : string -> Scope.item list -> Ir.unit_

(* the curry functions (ml_curry<n>_<k>: a closure of arity n given its
 * k+1-th argument), of every arity from 2 to the one given: the
 * program's, in its start object *)
val curry_funcs : int -> Ir.func list

(* a function not known where it is called, given as many arguments as
 * it takes (its closure says), called with them all; else, and when
 * off (mini-ml -calls), an argument at a time through the curry
 * functions *)
val calls_whole : bool ref

(* the symbols' names: an operator's characters as $ and their code *)
(* the runtime's function for a relation of values not both integers *)
val poly_function : Ir.rel -> string

val mangle : string -> string

(* a string's byte (the unchecked accessors') and its length as
 * instructions (Ir.ByteGet, ByteSet, StrLen), not calls of the runtime:
 * on, unless mini-ml -calls *)
val strings_in_place : bool ref
(* a float's arithmetic as the processor's instructions (Ir.Float2,
 * FloatOfInt, IntOfFloat), not calls of the runtime *)
val floats_in_place : bool ref
