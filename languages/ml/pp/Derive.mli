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
 * tests/pp/derive.ml has every shape, its output ppx_deriving's own.
 *
 * It is how the compilers of ix print their trees: mini-ml -dast,
 * -dscope and -dir are show of Ast's, Scope's and Ir's types, with
 * next to no printer written by hand.
 *
 * cs-history:
 * A printer made from the type is Haskell's deriving, in the
 * language from its first report (1990): the compiler writes the
 * instance of a few known classes, structurally. ML has no classes
 * for the compiler to write instances of, and got it from outside:
 * a preprocessor reads the declaration and writes a function named
 * after the type, pp_tree for tree, since nothing else ties the two
 * (for Camlp4 first, then ppx_deriving, 2014). Rust's
 * #[derive(Debug)] is the same idea.
 *
 * others:
 * Without it one writes the printer by hand and forgets to add the
 * new constructor, or one asks the runtime: OCaml's toplevel prints
 * any value because it has its type at hand, and a debugger walks
 * blocks and tags and prints constructors as numbers, which is all
 * that is left of a type in a running ML program (Gen.mli). *)

exception Error of string

(* the .ml's code, lines: let rec pp_... and let show_...; the module's
 * name, a constructor's prefix *)
val show : string -> Ast.type_decl list -> string

(* the .mli's: val pp_... and val show_... *)
val show_sig : Ast.type_decl list -> string

(* a class's methods, type 'a show = { show : 'a -> string } [@@class]:
 * each field a function of its dictionary, which a call doesn't write;
 * the .ml's lines, let show (d__ : [%using: 'a show]) = d__.show, and
 * the .mli's, val show : [%using: 'a show] -> 'a -> string *)
val accessors : Ast.type_decl -> string
val accessors_sig : Ast.type_decl -> string
