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
 *   through the closure's first field (curry functions, eval/apply);
 * - {b primitives}: an external "%name" an instruction, another a call
 *   of the runtime's C.
 *
 * The machine itself is Ir's. *)

(* a unit (its module's name), its init function M.init and the
 * curry functions it needs (ml_curry<n>_<k>, one per unit) *)
val unit_ : string -> Scope.item list -> Ir.unit_

(* the symbols' names: an operator's characters as $ and their code *)
(* the runtime's function for a relation of values not both integers *)
val poly_function : Ir.rel -> string

val mangle : string -> string
