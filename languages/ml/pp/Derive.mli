(* mlpp's deriving (plan_ml_bootstrap.md, decision 3): from a type
 * declaration's syntax alone, no types needed, a printer per type of
 * the group. Its text is ppx_deriving's show's, so that dune can build
 * ix with ppx_deriving itself, but on one line (ppx_deriving breaks a
 * long one): (M.C x), (M.C (a, b)), M.C {l = v; ...} for a constructor
 * of module M, { M.l = v; ... } a record, [a; b] a list, (a, b) a tuple.
 * Only the strings: ppx_deriving's pp_t, on a formatter, is not made.
 *
 * The printer of t is show, of u show_u; a type M.u in a component is
 * printed by M.show_u; a parameter 'a by an argument, poly_a (a
 * function to a string here, on a formatter for ppx_deriving: a type
 * with parameters is not printed the same way by the two):
 *
 *   type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree [@@deriving show]
 *   val show_tree : ('a -> string) -> 'a tree -> string *)

exception Error of string

(* the .ml's code, lines: let rec show_...; the module's name, a
 * constructor's prefix *)
val show : string -> Ast.type_decl list -> string

(* the .mli's: val show_... *)
val show_sig : Ast.type_decl list -> string
