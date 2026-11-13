(* Turns SQL text into a statement, as chidb's chisql_parser does.
 *
 * A ; is added if the text does not end with one. On a syntax error,
 * parse prints chidb's two lines on stderr:
 *
 *      syntax error (line 1)
 *      invalid sql: "SELEC x;"
 *
 * and returns None. When a text has several statements, they are all
 * parsed and the last one is kept, because chidb's parser overwrites
 * its statement for each one. A text with only empty statements (";")
 * is refused, where chidb crashes. This difference is deliberate:
 * chidb then reads the type of its uninitialized statement. *)

val parse : < Cap.stderr; .. > -> string -> Ast.t option

(* the last statement, without messages; it is used for the schema's
 * SQL *)
val parse_quiet : string -> Ast.stmt option
