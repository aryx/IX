(* Tiger's names and types checked (Appel's chapter 5), the tree made
 * again with its declarations in place of its names (Tiger_tree), and
 * Appel's escape analysis (his chapter 6) done on the way: a variable
 * used by a function other than the one that declares it escapes.
 *
 *     let var n := 0                   n: main's, escapes (count uses it)
 *         function count() = n := n + 1
 *     in count(); count(); printi(n) end
 *
 * The environments are lists, the innermost first: a declaration
 * hides an outer one of its name, and a group of types or functions
 * (consecutive declarations) is entered at once, so its members may
 * name each other: type tree = {key: int, left: tree, right: tree}.
 * A cycle of names alone (type a = b type b = a) is an error.
 *
 * Tiger's types are by name: two record types with the same fields are
 * two types, and nil goes where any record goes. *)

exception Error of string * Tiger_ast.pos

val program : Tiger_ast.exp -> Tiger_tree.program

(* a type as the errors say it *)
val show : Tiger_tree.ty -> string
