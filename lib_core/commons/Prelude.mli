(* Haskell's Prelude's classes, by mlpp's (plan_ml_bootstrap.md, "Type
 * classes"; mini-ml -pp): a class is a record type, an instance a value
 * of it, and a function with a constraint, Haskell's
 * (Show a) => a -> String, has a parameter [%using: 'a show], a
 * dictionary its calls don't write. So that a program says
 *
 *   open Prelude
 *   let describe [%using: 'a show] (xs : 'a list) = show (List.length xs) ^ " of " ^ show xs
 *   ... describe [ Some 1; None ] ...           "2 of [Some 1; None]"
 *   ... if p == q then ... sort names ...
 *
 * and mlpp writes the dictionaries, from the types:
 * describe (show_option show_int) [ Some 1; None ]. A type of a
 * program's gets an instance in its unit:
 *
 *   let show_point : Point.t show = { show = (fun p -> ...) } [@@instance]
 *
 * open Prelude changes what three names mean: compare is the class's
 * (ord), and == and != its equality (eq), not the same block in memory
 * (Stdlib's ( == ), then). <, <=, max... stay OCaml's, polymorphic:
 * through a dictionary they would be a call each.
 * A unit using it is preprocessed by mini-ml -pp with the stdlib's and
 * this directory's -I (the dune file here).
 *
 * cs-history:
 * Type classes are Philip Wadler and Stephen Blott's (1989), made
 * for Haskell: a way to have == and show at many types without
 * building them into the language, as ML had done for equality
 * alone. Their paper already gives the translation used here: a
 * class is a record of functions, a dictionary, an instance a value
 * of it, and a constrained function takes the dictionary as one more
 * argument that the compiler writes. What Haskell's compiler does
 * inside, mlpp does as text before the compiler.
 *
 * others:
 * OCaml has no classes of types: a polymorphic compare and = that
 * look at the values' representation as they run (and fail on a
 * function), printers written or derived by a ppx ([@@deriving
 * show]), and functors when a structure needs an order (Map.Make).
 * Modular implicits (White, Bour and Yallop, 2014) would have the
 * compiler find a module from the types, as here a dictionary; it
 * is not in OCaml. Scala's implicits and Rust's traits are the same
 * idea; Rust compiles a copy of the function for each type where
 * this passes a record.
 *
 * References: P. Wadler and S. Blott, "How to make ad-hoc
 * polymorphism less ad hoc", POPL 1989; plan_ml_bootstrap.md, "Type
 * classes", for mlpp's rules. *)

(* Show: a value as text, in OCaml's syntax *)
type 'a show = { show : 'a -> string } [@@class]

(* Eq: equality *)
type 'a eq = { equal : 'a -> 'a -> bool } [@@class]

(* Ord: a total order; compare a b is negative, zero or positive *)
type 'a ord = { compare : 'a -> 'a -> int } [@@class]

val ( == ) : [%using: 'a eq] -> 'a -> 'a -> bool
(* not equal: Haskell's, and OCaml's name for it *)
val ( /= ) : [%using: 'a eq] -> 'a -> 'a -> bool
val ( != ) : [%using: 'a eq] -> 'a -> 'a -> bool

val sort : [%using: 'a ord] -> 'a list -> 'a list
(* of a list that is not empty *)
val maximum : [%using: 'a ord] -> 'a list -> 'a
val minimum : [%using: 'a ord] -> 'a list -> 'a

(* The instances at the predefined types (those of a program's types
 * are in their units) *)

val show_int : int show [@@instance]
val show_bool : bool show [@@instance]
val show_char : char show [@@instance]
val show_string : string show [@@instance]
val show_float : float show [@@instance]
val show_unit : unit show [@@instance]
val show_int64 : int64 show [@@instance]
val show_list : [%using: 'a show] -> 'a list show [@@instance]
val show_array : [%using: 'a show] -> 'a array show [@@instance]
val show_option : [%using: 'a show] -> 'a option show [@@instance]
val show_pair : [%using: 'a show] -> [%using: 'b show] -> ('a * 'b) show [@@instance]
val show_triple : [%using: 'a show] -> [%using: 'b show] -> [%using: 'c show] -> ('a * 'b * 'c) show [@@instance]

val eq_int : int eq [@@instance]
val eq_bool : bool eq [@@instance]
val eq_char : char eq [@@instance]
val eq_string : string eq [@@instance]
val eq_float : float eq [@@instance]
val eq_unit : unit eq [@@instance]
val eq_int64 : int64 eq [@@instance]
val eq_list : [%using: 'a eq] -> 'a list eq [@@instance]
val eq_array : [%using: 'a eq] -> 'a array eq [@@instance]
val eq_option : [%using: 'a eq] -> 'a option eq [@@instance]
val eq_pair : [%using: 'a eq] -> [%using: 'b eq] -> ('a * 'b) eq [@@instance]
val eq_triple : [%using: 'a eq] -> [%using: 'b eq] -> [%using: 'c eq] -> ('a * 'b * 'c) eq [@@instance]

val ord_int : int ord [@@instance]
val ord_bool : bool ord [@@instance]
val ord_char : char ord [@@instance]
val ord_string : string ord [@@instance]
val ord_float : float ord [@@instance]
val ord_unit : unit ord [@@instance]
val ord_int64 : int64 ord [@@instance]
(* as the words of a dictionary: the first difference, or the shorter first *)
val ord_list : [%using: 'a ord] -> 'a list ord [@@instance]
(* None before Some *)
val ord_option : [%using: 'a ord] -> 'a option ord [@@instance]
val ord_pair : [%using: 'a ord] -> [%using: 'b ord] -> ('a * 'b) ord [@@instance]
val ord_triple : [%using: 'a ord] -> [%using: 'b ord] -> [%using: 'c ord] -> ('a * 'b * 'c) ord [@@instance]
