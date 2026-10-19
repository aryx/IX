(* Quickening: a program's tree copied with a little memory at each
   place that will be asked the same question many times.

   The parser's tree says what was written, and nothing in it changes:
   a name is Name "total". Looked for by its name, it costs the same
   the millionth time as the first (Js_scope's simple way). The fast
   way wants to keep, at that very place in the program, where the name
   was found the last time. So before a program runs, here, each of
   these becomes a node of another kind, made for it:

     Name "total"                        Local ("total", a place)
     var i = 0, n                        Var_set [ ("i", a place, Some 0); ("n", a place, None) ]
     function add(a, b) { ... }          the same, its [frame] the layout of its calls
                                         (Js_frame.layout)

   and the rest is copied as it is. The evaluator has a case for each:
   Local's reads the place (Js_scope.find) where Name's goes up the
   scopes; Var_set's is a var's assignment by a place; a call whose
   function has a frame is made the fast way (Js_frame.opti). A tree
   not quickened runs too, the simple way: an engine made with
   Mini_opti off never comes here, and that is the whole of the switch.

   Nothing is decided here: no scope is known, no name is resolved.
   The places start empty and are filled as the program runs. That is
   what keeps this pass forty lines of copying, with nothing of the
   language's rules for scopes in it (others: Js_scope.mli).

   cs-history:
   The word is the Java virtual machine's: Sun's first interpreter
   rewrote an instruction, the first time it ran, into a _quick form
   that skipped the lookup in the class's constants (Lindholm and
   Yellin, The Java Virtual Machine Specification, 1996, which tells
   it in a chapter the later editions dropped). Brunthaler joined it
   to the inline cache for an interpreter with no compiler behind
   (Inline Caching Meets Quickening, ECOOP 2010), and CPython took
   that road with its "specializing adaptive interpreter" (PEP 659,
   Python 3.11, 2022): a bytecode rewritten in place to the form that
   fits what it has seen.

   others:
   There the instruction is rewritten when it first runs, and back if
   it guessed wrong. Here the node is made before the run and stays;
   what changes is the place in it. *)
(* ix: the author's mini-chrome's languages/javascript/eval/Js_quicken.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* the program's copy, its names, var's and functions quickened; what
 * is already so is left *)
val program : Js_ast.program -> Js_ast.program

(* a function alone: one the evaluator makes itself (a class's
 * constructor that was not written) *)
val func : Js_ast.func -> Js_ast.func
