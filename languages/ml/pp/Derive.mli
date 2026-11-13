(* mlpp's deriving (plan_ml_bootstrap.md, decision 3). From a type
 * declaration's syntax alone, with no types needed, it writes the
 * printers of each type of the group that ppx_deriving's show writes:
 * the same functions, printing the same text, with the same boxes and
 * line breaks (Format's). So dune builds ix with ppx_deriving itself,
 * and mini-ml builds it with this. The text is:
 * - (M.C x), (M.C (a, b)) or M.C {l = v; ...} for a constructor of
 *   module M;
 * - { M.l = v; ... } for a record;
 * - [a; b] for a list, and (a, b) for a tuple.
 *
 * For t, the printers are pp, on a formatter, and show, which returns
 * a string; for u, they are pp_u and show_u. A type M.u in a
 * component is printed by M.pp_u. A parameter 'a is printed by an
 * argument, poly_a, also on a formatter:
 *
 *   type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree [@@deriving show]
 *   val pp_tree : (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a tree -> unit
 *   val show_tree : (Format.formatter -> 'a -> unit) -> 'a tree -> string
 *
 * tests/pp/derive.ml has every shape, and its output is the same as
 * ppx_deriving's.
 *
 * It is how the compilers of ix print their trees: mini-ml -dast,
 * -dscope and -dir use the show functions of Ast's, Scope's and Ir's
 * types, with next to no printer written by hand.
 *
 * cs-history:
 * A printer made from the type is Haskell's deriving, which has been
 * in the language since its first report (1990): the compiler writes
 * the instance of a few known classes, following the structure of the
 * type. ML has no classes for the compiler to write instances of, and
 * got the feature from outside: a preprocessor reads the declaration
 * and writes a function named after the type, pp_tree for tree, since
 * nothing else ties the two (first for Camlp4, then in ppx_deriving,
 * 2014). Rust's #[derive(Debug)] is the same idea.
 *
 * others:
 * Without it one writes the printer by hand and forgets to add the
 * new constructor, or one asks the runtime: OCaml's toplevel prints
 * any value because it has its type at hand, and a debugger walks
 * blocks and tags and prints constructors as numbers, which is all
 * that is left of a type in a running ML program (Gen.mli). *)

exception Error of string

(* the code for the .ml, as lines: let rec pp_... and let show_...;
 * the module's name is given, as a constructor's prefix *)
val show : string -> Ast.type_decl list -> string

(* the lines for the .mli: val pp_... and val show_... *)
val show_sig : Ast.type_decl list -> string

(* a class's methods, for type 'a show = { show : 'a -> string }
 * [@@class]: each field becomes a function of its dictionary, which a
 * call does not write. accessors gives the .ml's lines, let show
 * (d__ : [%using: 'a show]) = d__.show, and accessors_sig the .mli's,
 * val show : [%using: 'a show] -> 'a -> string *)
val accessors : Ast.type_decl -> string
val accessors_sig : Ast.type_decl -> string
