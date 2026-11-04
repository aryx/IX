(* An ML unit's tree as Datalog facts
 * (docs/plans/done/plan_bug_analyses.md, A12): each expression a node,
 * its kind, its children in the text's order, where it starts in the
 * file. For rules over the text's shape,
 * bugs/layout.dl first, joined if need be with the others' facts:
 *
 *   expr(N, Kind)        N is an expression: if, seq, apply, let, ...
 *   child(P, K, N)       N is P's K-th child (an if: its test 0, its
 *                        then 1, its else 2; a seq: 0 then 1)
 *   pos(N, Line, Col)    where N starts (Col from 0)
 *   leading(N)           nothing but blanks before N on its line
 *
 * Only the program's own units (Ml_front), not the library's: what a
 * layout rule reports is the program's text.
 *
 * design:
 * The tree is mini-ml's scoped one (Scope), the one Closure_facts reads:
 * a parenthesis is gone, but an expression's span still says where it
 * starts. A text rewritten by mlpp (a class, a [@@deriving]) has its
 * spans in the rewritten text: its columns may be off.
 *
 * others:
 * CodeQL keeps a program's whole tree in its database beside the
 * data flow (its AST classes, Expr.getParent()); Semgrep matches
 * patterns on the tree without a database; Datalog over a tree goes
 * back to Paul Klint's and Jurgen Vinju's Rascal and to "Scalable and
 * flexible ... Doop"'s fact generators, which also say each node. *)

(* the unit [name]'s facts, through Closure_facts.added; [text] the file's,
 * for the lines and the columns *)
val unit_ : string -> string -> Scope.item list -> unit
