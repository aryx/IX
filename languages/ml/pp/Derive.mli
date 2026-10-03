(* mlpp's deriving (plan_ml_bootstrap.md, decision 3): from a type
 * declaration's syntax alone, no types needed, the printers of each
 * type of the group, ppx_deriving's show's: the same functions, and the
 * same text, with its boxes and its line breaks (Format's), so that
 * dune builds ix with ppx_deriving itself and mini-ml with this:
 * (M.C x), (M.C (a, b)), M.C {l = v; ...} for a constructor of module
 * M, { M.l = v; ... } a record, [a; b] a list, (a, b) a tuple.
 *
 * Of t: pp, on a formatter, and show, its string; of u: pp_u and
 * show_u. A type M.u in a component is printed by M.pp_u; a parameter
 * 'a by an argument, poly_a, on a formatter too:
 *
 *   type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree [@@deriving show]
 *   val pp_tree : (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a tree -> unit
 *   val show_tree : (Format.formatter -> 'a -> unit) -> 'a tree -> string
 *
 * tests/pp/derive.ml has every shape, its output ppx_deriving's own. *)

exception Error of string

(* the .ml's code, lines: let rec pp_... and let show_...; the module's
 * name, a constructor's prefix *)
val show : string -> Ast.type_decl list -> string

(* the .mli's: val pp_... and val show_... *)
val show_sig : Ast.type_decl list -> string
