(* acid's code printed back (principia's print.c: pcode, pexpr), as
 * whatis prints a function:
 *
 *     defn fact(n) {
 *         if (n<=1) then
 *             return 1;
 *         return (n*fact((n-1)));
 *     }
 *
 * a binary operation in parentheses, without blanks, a tab a level,
 * braces around a body of more than one statement. *)

val expr : Ast.expr -> string

(* the statements at a depth (tabs), a line each *)
val stmts : int -> Ast.stmt list -> string
