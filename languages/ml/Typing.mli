(* Types inferred, then forgotten (plan_ml.md, decision 4; the
 * tutorial's section 6). Hindley-Milner's algorithm over Scope's tree:
 * type variables are cells, unified in place (union-find); a let's
 * variables deeper than its level are generalized (Remy's levels, as
 * OCaml's), and only a value's (Wright's value restriction); an
 * abbreviation is expanded when two types' heads differ. A string
 * where Printf expects a format is typed by its conversions (%d an int,
 * %s a string, %a a printer and its argument...), the one special
 * case of ocaml-light's checker.
 *
 * Inference is solving equations. Each name and each expression gets
 * a type, a variable when nothing is known yet, and each construct
 * says two types are the same, which unification makes true by
 * linking variables (or fails: the type error):
 *
 *     let compose f g = fun x -> f (g x)      f : 'f   g : 'g   x : 'x
 *
 *     g x        g is a function taking x:    'g = 'x -> 'a
 *     f (g x)    f one taking g x's result:   'f = 'a -> 'b
 *     compose : ('a -> 'b) -> ('x -> 'a) -> 'x -> 'b
 *
 * and no equation says more of 'a, 'b or 'x, so compose works at any
 * types: mini-ml -i prints ('a -> 'b) -> ('c -> 'a) -> 'c -> 'b.
 * A variable that would have to hold itself (let f x = x x: 'x =
 * 'x -> 'a) is "a type would be recursive", unify's occurs check.
 *
 * When a variable is one a program may use at many types is the whole
 * question, and its answer is let:
 *
 *     let pair = let id x = x in (id 1, id "a")      int * string
 *     let f = fun id -> (id 1, id "a")               an error: string
 *                                                    is used as int
 *
 * A let's definition is typed first, alone, and the variables left in
 * its type that nothing outside knows are generalized: each use of id
 * then has a copy of 'a -> 'a with a variable of its own. A function's
 * parameter has one type in its body. Which variables nothing outside
 * knows is the levels' work: a variable remembers how deep in the lets
 * it was made, unifying it with an older one lowers it, and those
 * still deeper than the let at its end are its own. And only a value
 * is generalized:
 *
 *     let r = ref []          '_a list ref: one list, of one type
 *     r := [ 1 ]; r := [ "a" ]   the second is the error
 *
 * since ref [] is a call, which makes one cell: generalized, the cell
 * would take integers and give them back as strings.
 *
 * Nothing after this pass reads a type: Lower compiles the tree it
 * checked. So a program ocaml-light accepts compiles without it
 * (-unsafe-types), and the tests compare what it accepts, and what
 * -i prints, with ocaml-light's.
 *
 * The unit's own .mli, when it has one, is checked: each val's
 * declared type an instance of the inferred one. Another unit's values
 * have their .mli's types (a unit without one: a fresh variable, not
 * checked).
 *
 * The same unification, of terms whose variables are linked in place,
 * is Prolog's (mini-prolog's Prolog_machine.unify, which leaves the
 * occurs check out, as Prologs do). mlpp's classes are found here too,
 * from the types (the dictionaries below; Pp.mli has their story).
 *
 * cs-history:
 * The algorithm was found twice. Roger Hindley (1969), a logician,
 * showed that a term of combinatory logic has a most general type,
 * the principal type, and that it can be computed, using Alan
 * Robinson's unification (1965), made for theorem provers. Robin
 * Milner (1978), who did not know of it, found it again for ML, with
 * what a programming language needs: let, and the theorem that a
 * program that passes cannot apply an integer or add a function,
 * well-typed programs cannot go wrong. Luis Damas, his student,
 * proved with him (1982) that the algorithm, W, finds the principal
 * type whenever the program has a type at all.
 *
 * design:
 * Why let and not every function. If a parameter could be used at
 * many types (the second example above), a function's type would say
 * for all inside an arrow's argument; that is System F, where
 * finding the types of a program with no annotation is undecidable
 * (Joe Wells, 1994). ML's cut, polymorphism at let only, is where
 * inference is still complete, and it is why a file of ML has so
 * few types written in it.
 *
 * evolution:
 * The reference broke the first rule. Standard ML (1990) had
 * variables of a second kind, imperative ones, for the types that
 * a reference might hold, and rules for them that were hard to
 * explain. Andrew Wright (1995) counted how many
 * real programs a far simpler rule rejects, generalizing only what
 * is syntactically a value, and it was nearly none: Standard ML
 * (1997) and OCaml took it. OCaml later relaxed it for the variables
 * that are only in covariant places (Jacques Garrigue, 2004); not
 * here.
 *
 * modern:
 * W as first written generalizes by looking through the whole
 * environment for the variables a type shares with it, at each let.
 * The levels (Didier Remy, 1992) make that a comparison of two
 * integers, and are how OCaml's checker goes about it. In theory
 * inference takes exponential time (Harry Mairson, 1990: a tower of
 * lets each using the one before twice); nobody writes that program.
 * Haskell, F#, Elm, and in part Rust and Swift infer types this way
 * or start from it.
 *
 * References: Robin Milner, "A Theory of Type Polymorphism in
 * Programming" (Journal of Computer and System Sciences 17, 1978);
 * Luis Damas and Robin Milner, "Principal type-schemes for functional
 * programs" (POPL 1982): six pages, the rules and the definition; Roger
 * Hindley, "The principal type-scheme of an object in combinatory
 * logic" (Transactions of the AMS 146, 1969); J. A. Robinson, "A
 * machine-oriented logic based on the resolution principle" (Journal
 * of the ACM 12, 1965); Andrew Wright, "Simple imperative
 * polymorphism" (Lisp and Symbolic Computation 8, 1995); Oleg
 * Kiselyov, "How OCaml type checker works -- or what polymorphism and
 * garbage collection have in common" (okmij.org, 2013), the levels
 * explained, which is the text to read before Typing.ml; Jacques
 * Garrigue, "Relaxing the value restriction" (FLOPS 2004); ocaml-light's
 * typecore.ml and ctype.ml. *)

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
