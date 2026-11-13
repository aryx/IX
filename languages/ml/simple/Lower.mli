(* This pass goes from Scope's tree to a stack machine, Ir's
 * (plan_ml.md, decision 6: TinyC's design, and tiny-ml's, whose code
 * this generalizes). What the plan called Lambda, Match and Closure is
 * here, each as a part:
 *
 * - {b patterns} become a sequence of tests, each jumping to the next
 *   clause when it fails (the tutorial's section 7), with the clauses
 *   in order;
 * - {b closures}: a function is code with its closure in slot 0 and its
 *   parameters after it, and its free variables are fields of the
 *   closure. A function without free variables is a static block. A
 *   call of a known function (a let or a toplevel of this unit) with
 *   all its arguments is a direct call. Any other call passes one
 *   argument at a time through the closure's first field (curry
 *   functions, eval/apply), unless the closure says that it takes them
 *   all (calls_whole);
 * - {b primitives}: an external "%name" becomes an instruction, and
 *   another external becomes a call of the runtime's C.
 *
 * Here is a match, in the instructions that mini-ml -dir prints,
 * shortened (Circle is the block of tag 0, Rect the block of tag 1,
 * and Dot the integer 0; these are Scope's numbers):
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
 * Here is a closure, for the function that is made anew at each call
 * of scale:
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
 * unknown f is right whatever f's arity, at the cost of a block. When
 * f's field 0 is ml_curry2_0 itself, f is a function of exactly two
 * arguments, and the call goes straight to field 1 (calls_whole).
 *
 * The collector has its say in all of it. A block's fields are
 * values, so the code addresses in a closure are told apart by the
 * tag (247, OCaml's Closure_tag). And every slot is a value or 0 at
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
 * Passing several arguments at once. Here, as in ocamlopt (its caml_curry
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

(* a unit, given its module's name, with its init function M.init *)
val unit_ : string -> Scope.item list -> Ir.unit_

(* the curry functions (ml_curry<n>_<k> gives a closure of arity n its
 * k+1-th argument), of every arity from 2 to 7. They are the
 * program's, in its start object; a unit has its own for a greater
 * arity. *)
val curry_funcs : unit -> Ir.func list

(* When on, a function that is not known where it is called, and is
 * given as many arguments as it takes (its closure says how many), is
 * called with them all. Otherwise, and when this is off (mini-ml
 * -calls), it is called with one argument at a time through the curry
 * functions. *)
val calls_whole : bool ref

(* When on, each call of an application is preceded by an Ir.Site, the
 * span of the function applied, which the SSA keeps (Ssa.func's
 * sites). It is for mini-analyze -bugs (Ml_flow), to name the SSA's
 * calls as its facts name them. It is off for the compiler: there is
 * no Site, and the code is the same. *)
val sites : bool ref

(* the code labels of the functions marked [@@zero_alloc]
 * (Annotations.zero_allocs), each with its name, for ssa's
 * Zero_alloc *)
val zero_allocs : (string, string) Hashtbl.t
(* the floats marked [@@unboxed_float] (Annotations.unboxed_floats),
 * keyed by their function's code label and their slot, with their name
 * and line, for ssa's Unbox.check *)
val unboxed_floats : (string * int, string * int) Hashtbl.t
(* A known function whose body has this many nodes or fewer is
 * inlined: its calls with all its arguments are replaced by its body,
 * in its unit (0 means none; -O3 sets it). *)
val inline_most : int ref
(* the toplevel functions of the units that this one names (from their
 * summaries), to be inlined in this one too; set before unit_ *)
val imports : Summary.entry list -> unit
(* this unit's toplevel functions that are inlined where they are
 * called, for its summary; called after unit_ *)
val exports : Scope.item list -> Summary.entry list

(* the runtime's function for a relation between two values that are
 * not both integers *)
val poly_function : Ir.rel -> string
(* the runtime's function that does what a primitive of Ir does
 * (Float2 Add: caml_addfloat...). simple's code calls it, and ssa's
 * code calls it when the primitive is not done in place or when there
 * is no room *)
val runtime_function : Ir.t -> string

(* the symbols' names: an operator's characters are written as $ and
 * their code *)
val mangle : string -> string

(* the places of the comparisons on immediates (Typing.immediates),
 * which are compiled as comparisons of integers (Ir.Cmp), not as
 * compare (Ir.Poly), and of the stores of immediates, which are
 * compiled without a write barrier; set before unit_ *)
val immediates : (Ast.span, unit) Hashtbl.t
(* the places of = and <> on strings (Typing.strings), which call the
 * runtime's caml_string_equal and notequal; set before unit_ *)
val string_eqs : (Ast.span, unit) Hashtbl.t
(* the places of the comparisons on floats (Typing.floats), compiled
 * as Ir.FloatCmp; set before unit_ *)
val float_cmps : (Ast.span, unit) Hashtbl.t
(* the functions min and max, inlined on ints or floats, with the
 * relation of their test (Typing records their places too) *)
val min_max : (string * Ir.rel) list
(* the globals that are min or max, each with the one it is; set before
 * unit_ *)
val min_max_aliases : (string, string) Hashtbl.t

(* In place: a primitive of the runtime (a C function such as
 * ml_string_get, caml_addfloat or int32_add) is written as the
 * processor's instructions where it is used. It gets its own Ir
 * instruction, which ssa's Emit spells out (simple's Gen calls the
 * runtime for each), and the runtime's function is called only on the
 * rare path (when there is no room in the heap for the result's
 * block). The classic name is open coding (MacLisp's compiler
 * open-coded car and the arithmetic; a C compiler has intrinsics, as
 * when gcc makes a memcpy of 8 bytes two moves). It is not inlining,
 * which copies an ML function's body: here the compiler knows what
 * each primitive means, one by one. Emit.alloc_in_place does the same
 * for the allocation. All are on, unless mini-ml -calls is given. *)

(* a string's byte (checked or not) and its length, as
 * instructions (Ir.ByteGet, ByteSet, StrLen) *)
val strings_in_place : bool ref
(* a float's arithmetic as the processor's instructions (Ir.Float2, Float1,
 * FloatOfInt, IntOfFloat) *)
val floats_in_place : bool ref
(* an int32's arithmetic, logic and shifts as the processor's
 * instructions, with the result's block taken in place (Ir.Int32) *)
val ints_in_place : bool ref

(* a match on four constructors or more, compiled to a jump table
 * (Ir.Switch) *)
val switches : bool ref
