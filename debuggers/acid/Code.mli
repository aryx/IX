(* Prints acid's code back (principia's print.c: pcode, pexpr), as
 * whatis prints a function:
 *
 *     defn fact(n) {
 *         if (n<=1) then
 *             return 1;
 *         return (n*fact((n-1)));
 *     }
 *
 * A binary operation is put in parentheses, without blanks; each level
 * is indented by a tab; and braces go around a body of more than one
 * statement. *)

val expr : Ast.expr -> string

(* the statements at a depth (in tabs), one line for each *)
val stmts : int -> Ast.stmt list -> string
