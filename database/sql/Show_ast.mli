(* Prints a statement as chidb's shell prints it (.parse, .opt): the
 * tree of the algebra, indented, in chidb's own format. mini-chidb's
 * output is compared with chidb's, so this printer is written by hand,
 * not derived. *)

(* what .parse prints, the final newline included *)
val show : Ast.t -> string
val show_sra : Ast.sra -> string
val show_cond : Ast.cond -> string
val show_expr : Ast.expr -> string
