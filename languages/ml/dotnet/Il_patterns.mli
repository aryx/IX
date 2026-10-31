(* A pattern tested on a value (Lower_il's match, try, let and
 * functions of cases): constants by comparisons, a constructor by
 * isinst on its class then its fields after a cast, a record by its
 * fields, an or-pattern by its left then its right; on failure a jump
 * to a label, on success its variables bound in locals. *)

(* a variable bound to the value [load] pushes, in a local of its own *)
val bind : Il_code.c -> Il_code.code -> Scope.var -> (unit -> unit) -> unit

(* the pattern tested on the value [load] pushes, of an ML type: to
 * the label [fail] if it does not match *)
val pattern : Il_code.c -> Il_code.code -> (unit -> unit) -> Scope.ty -> Scope.pattern -> int -> unit
