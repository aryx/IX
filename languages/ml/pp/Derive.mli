(* mlpp's poor man's deriving (plan_ml_bootstrap.md, decision 3): from a
 * type declaration's syntax alone, no types needed, a printer per type
 * of the group, as S-expressions, ix's dumps' way: (C a b) for a
 * constructor, {(l v) ...} a record, [a b] a list, (a, b) a tuple.
 *
 * The printer of t is show, of u show_u; a type M.u in a component is
 * printed by M.show_u; a parameter 'a by an argument, poly_a:
 *
 *   type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree [@@deriving show]
 *   val show_tree : ('a -> string) -> 'a tree -> string *)

exception Error of string

(* the .ml's code, starting with a newline: let rec show_... *)
val show : Ast.type_decl list -> string

(* the .mli's: val show_... *)
val show_sig : Ast.type_decl list -> string
