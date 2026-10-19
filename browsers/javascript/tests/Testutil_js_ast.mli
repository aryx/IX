(* Testutil_js_ast: a tree of Js_ast as text, for a test to compare
   (Unit_js_parse, Unit_js_classic). Js_ast's once; the browser prints
   no tree. *)

(* fully parenthesized: (1 + (2 * 3)), f((x) => (x * 2), 3) *)
val expr_to_string : Js_ast.expr -> string

(* one line per statement, a body's statements in brackets:
 *   Let a 1
 *   If ((b > a), Block [Expr (b = 0)], Expr (b = 1))
 *   Function f [] [Return; Expr a] *)
val stmt_to_string : Js_ast.stmt -> string
