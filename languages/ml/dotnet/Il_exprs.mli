(* An expression's IL (Lower_il.mli's table, but for a unit's items): a
 * value left on the stack, unit's nothing; in tail position every path
 * returned, a call there a tail call. The closures, the calls, the
 * primitives, a match's cases and a try's are here, one recursion. *)

(* an expression's value pushed (none for unit's) *)

(* Lower_il's define, set by it: a local function lifted to a method
 * (its body made as a function of the unit's) *)
val define_hook : (Il_code.c -> Il_functions.env -> Il_functions.fn -> unit) ref

val expr : Il_code.c -> Il_functions.env -> Il_code.code -> Scope.expr -> unit

(* an expression for its effect: its value, if any, popped *)
val drop : Il_code.c -> Il_functions.env -> Il_code.code -> Scope.expr -> unit

(* an expression in tail position, its value returned ([boxed]: the
 * method returns an object for unit, a closure's Invoke) *)
val tail_expr : Il_code.c -> Il_functions.env -> Il_code.code -> Scope.expr -> bool -> unit

(* a match's cases on the value [load] pushes, of a type, each body in
 * tail position *)
val tail_cases :
  Il_code.c -> Il_functions.env -> Il_code.code -> (unit -> unit) -> Scope.ty -> Scope.case list -> bool -> unit
