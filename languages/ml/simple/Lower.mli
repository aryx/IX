(* From Scope's tree to a stack machine, Ir's (plan_ml.md, decision 6:
 * TinyC's design, and tiny-ml's, whose code this generalizes). What
 * was Lambda, Match and Closure in the plan is here, each a part:
 *
 * - {b patterns} a sequence of tests, each jumping to the next clause
 *   (the tutorial's section 7): the clauses in order;
 * - {b closures}: a function is code with its closure in slot 0 and its
 *   parameters after, its free variables fields of the closure; a
 *   function without free variables is a static block; a call of a
 *   known function (a let or a toplevel of this unit) with all its
 *   arguments is a direct call, any other one argument at a time
 *   through the closure's first field (curry functions, eval/apply),
 *   unless its closure says it takes them all (calls_whole);
 * - {b primitives}: an external "%name" an instruction, another a call
 *   of the runtime's C.
 *
 * A match, in the instructions mini-ml -dir prints, shortened (Circle
 * is the block of tag 0, Rect of tag 1, Dot the integer 0: Scope's
 * numbers):
 *
 *     match s with                  get s; int 0; eq; jz L5
 *     | Dot -> 0                      int 0; ret
 *     | Circle r -> 3 * r * r     L5: get s; isint; jnz L6
 *     | Rect (w, h) -> w * h          get s; tag; int 0; eq; jz L6
 *                                     get s; field 0; set r; ...; ret
 *                                 L6: get s; isint; jnz L7
 *                                     get s; tag; int 1; eq; jz L7
 *                                     get s; field 0; set w
 *                                     get s; field 1; set h; ...; ret
 *                                 L7: Match_failure raised
 *
 * Each clause asks again what the one before found out (is s an
 * integer?): the price of compiling the clauses one by one. Nothing
 * says whether the clauses cover every case, either: no warning for
 * a match that is not exhaustive, which is found at L7, running.
 *
 * A closure, for the function made anew at each call of scale:
 *
 *     let scale n l = List.map (fun x -> x * n) l
 *
 *       a block of tag 247        the code, f5_fun:
 *     +---------------------+       get 0; field 2     n, from the closure
 *     | 0  f5_fun (to call) |       get 1              x
 *     | 1  f5_fun (all args)|       mul; ret
 *     | 2  n                |
 *     +---------------------+
 *
 * The caller knows nothing of the function but this block: it puts
 * the block in slot 0, the argument in slot 1, and jumps to field 0.
 * So a function of two arguments has in field 0 not its code but
 * ml_curry2_0, which takes one argument and returns a block
 * [ml_curry2_1; the closure; the argument], and ml_curry2_1, given
 * the second, calls the code of field 1 with both. f x y on an
 * unknown f is right whatever f's arity, at a block's cost; when f's
 * field 0 is ml_curry2_0 itself, f is a function of two exactly, and
 * the call goes straight to field 1 (calls_whole).
 *
 * The collector has its say in all of it: a block's fields are
 * values, so the code's addresses in a closure are told apart by the
 * tag (247, OCaml's Closure_tag), and every slot is a value or 0 at
 * each call and each allocation, where a collection may start (Gen).
 *
 * cs-history:
 * The closure is Peter Landin's (1964), with the word: to evaluate
 * a lambda expression on a machine, his SECD machine pairs it with
 * the environment it is met in. Lisp, older, looked a free variable
 * up in the callers' bindings at the time of the call, which gives a
 * function passed or returned the wrong variables (the funarg
 * problem); Scheme (Gerald Sussman and Guy Steele, 1975) was the
 * Lisp with Landin's rule, and ML had it from the start.
 *
 * terminology:
 * A flat closure, as here and in OCaml, copies the values of its
 * free variables into its block: reading one is one load, and the
 * block keeps alive nothing but what the function uses. A linked
 * closure points to the frame it was made in, which costs nothing
 * to make and a chain of loads to use. Copying a variable is right
 * only because an ML variable never changes: a ref is a block, and
 * the copy is of its address.
 *
 * others:
 * Several arguments at once. Here, as in ocamlopt (its caml_curry
 * and caml_apply functions), the caller looks at the function's
 * arity and decides: eval/apply. In push/enter the caller pushes
 * what it has and the function, entered, counts what is on the
 * stack: Caml Light's ZINC machine was designed around it, so that
 * f x y allocates nothing, and so was GHC, until Simon Marlow and
 * Simon Peyton Jones measured both (2004) and changed it to
 * eval/apply: about as fast, and simpler to compile to native code.
 *
 * modern:
 * OCaml does not compile a match a clause at a time. Its matching.ml
 * looks at the clauses together, a column of patterns at a time, so
 * that no test is made twice when it can be avoided (backtracking
 * automata: Fabrice Le Fessant and Luc Maranget, 2001), switches on
 * a tag through a table of jumps, and the same matrix of clauses
 * gives the warnings for a case forgotten and a clause never
 * reached. A decision tree (Maranget, 2008) never tests twice, and
 * may be large: the better version to try here.
 *
 * others:
 * C has the code without the environment: a pointer to a function,
 * and by convention a second argument of type void* that the caller
 * gives back. qsort's comparison has no such argument, which is why
 * it cannot compare by a key chosen at run time without a global.
 * Java, C++ and Rust all got closures in the end.
 *
 * References: P. J. Landin, "The mechanical evaluation of
 * expressions" (The Computer Journal 6, 1964); Lennart Augustsson,
 * "Compiling pattern matching" (FPCA 1985), the first account;
 * Fabrice Le Fessant and Luc Maranget, "Optimizing pattern matching"
 * (ICFP 2001), OCaml's way; Luc Maranget,
 * "Compiling pattern matching to good decision trees" (ML Workshop
 * 2008); Simon Marlow and Simon Peyton Jones, "Making a fast curry:
 * push/enter vs. eval/apply for higher-order languages" (ICFP 2004);
 * Xavier Leroy, "The ZINC experiment" (1990), for why currying is
 * the case to make fast; ocaml-light's closure.ml and
 * translcore.ml. *)

(* a unit (its module's name) and its init function M.init *)
val unit_ : string -> Scope.item list -> Ir.unit_

(* the curry functions (ml_curry<n>_<k>: a closure of arity n given its
 * k+1-th argument), of every arity from 2 to the one given: the
 * program's, in its start object *)
val curry_funcs : int -> Ir.func list

(* a function not known where it is called, given as many arguments as
 * it takes (its closure says), called with them all; else, and when
 * off (mini-ml -calls), an argument at a time through the curry
 * functions *)
val calls_whole : bool ref

(* the symbols' names: an operator's characters as $ and their code *)
(* the runtime's function for a relation of values not both integers *)
val poly_function : Ir.rel -> string

val mangle : string -> string

(* a string's byte (the unchecked accessors') and its length as
 * instructions (Ir.ByteGet, ByteSet, StrLen), not calls of the runtime:
 * on, unless mini-ml -calls *)
val strings_in_place : bool ref
(* a float's arithmetic as the processor's instructions (Ir.Float2,
 * FloatOfInt, IntOfFloat), not calls of the runtime *)
val floats_in_place : bool ref
