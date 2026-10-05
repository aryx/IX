(* Types inferred, then forgotten (plan_ml.md, decision 4; the
 * tutorial's section 6). Hindley-Milner's algorithm over Scope's tree:
 * type variables are cells, unified in place (union-find); a let's
 * variables deeper than its level are generalized (Rémy's levels, as
 * OCaml's), and only a value's (Wright's value restriction); an
 * abbreviation is expanded when two types' heads differ. A string
 * where Printf expects a format is typed by its conversions (%d an int,
 * %s a string, %a a printer and its argument...), the one special
 * case of ocaml-light's checker.
 *
 * Nothing after this pass reads a type: Lower compiles the tree it
 * checked. So a program ocaml-light accepts compiles without it
 * (-unsafe-types), and the tests compare what it accepts, and what
 * -i prints, with ocaml-light's.
 *
 * The unit's own .mli, when it has one, is checked: each val's
 * declared type an instance of the inferred one. Another unit's values
 * have their .mli's types (a unit without one: a fresh variable, not
 * checked). *)

exception Error of int * string

(* a unit's items checked; the toplevel's values and their types, as
 * -i prints them *)
val unit_ : string -> Scope.item list -> (string * string) list

(* mlpp: the classes' dictionaries the unit just checked leaves to mlpp
 * (Resolve's implicit): where a name is, in the text, its line, and
 * what is to be written after it, show_list show_int, or why nothing
 * is (no instance). Then unit_ doesn't stop at a definition's type
 * error: errors has them, their lines and messages, and a definition
 * with one has the dictionaries that were found *)
val dictionaries : unit -> (Ast.span * int * (string, string) result) list
val errors : unit -> (int * string) list
