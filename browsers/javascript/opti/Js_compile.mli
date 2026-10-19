(* A function's body compiled to closures: the tree read once, not at
   each call.

   Js_eval walks the tree: to add two numbers a million times it asks
   a million times what kind of node this is, which operator "+" names,
   whether the statement is the last of its block. None of the answers
   change. Here those questions are asked once, when a function is
   first called, and what is left is kept as an OCaml function that
   does the rest:

     s = s + i          Assign ("=", Local s, Binary ("+", Local s, Local i))

     walked             eval_expr matches Assign, then "=", then Local;
                        calls itself on the Binary, matches it, calls
                        Js_operators.arithmetic, which looks "+" up
                        among thirty names...  each time

     compiled           let a = expr s and b = expr i and add = binary "+" in
                        fun scope this -> ... add (a scope this) (b scope this)
                        made once; called each time

   An expression becomes a [scope -> this -> value], a statement a
   [scope -> this -> outcome], each made from those of its parts: the
   tree's shape is in how the closures hold one another, and running
   the program is calling the outermost.

   **What is compiled** is what a program spends its time in: numbers,
   strings and names, the operators, a property and an item read and
   set, a call, an array, a function made; if, the loops, a block,
   switch, try, return, throw. **What is not** is left to the
   evaluator, node by node, by a closure that calls it on that part of
   the tree ([walk]): a class, a template, a spread, a pattern, with, a
   generator's yield, a loop with a label... So nothing of the language
   is written twice that did not have to be, and what the evaluator
   does for a node is the definition: where the two could differ, the
   compiled case is the evaluator's lines again, in the same order (who
   is evaluated first, which step of the budget is taken where, which
   scope a block makes).

   Clearly apart: the evaluator knows nothing of this module but one
   reference it calls if it is set ([Js_eval.compiler], set here when
   the program starts: the library is linked whole for that), at a
   function's first call, and the place where the result is kept, the
   function's [frame] in the quickened tree (Js_ast.code). With
   Mini_opti.compiled off, or Mini_opti.enabled off, no line of this
   file runs.

   What it bought, 2026-10-04 (mini-chrome's scripts/perf/Js_bench.exe,
   measured there, by OCaml's native compiler; compile=off
   is the evaluator, with Js_scope's places and the rest; the last
   column is Node's interpreter, its compiler off: node --jitless):

                                   compile=off   compiled   Node's
     a loop, 3M turns                1,040 ms      515 ms   108 ms
     calls, 1M                         610         350       61
     properties, 1M                    430         280       59
     arrays, 1M                        390         175       47
     closures, 300,000                 215         137       53
     the Playground's menu, a frame    190         130

   In two rounds. The first was the compiling itself: a quarter on a
   real program, not the several times hoped for. The second came from
   counting what a frame of that program asks (a million names read,
   300,000 operators, 125,000 calls, 116,000 scopes made for blocks
   that declare nothing, 34,000 typeof and 16,000 instanceof left to
   the evaluator, a regexp read again 6,500 times), and answering each
   where it is asked: the comments below starting "opti:" or giving a
   count are those. What is left is what a tree and its closures
   share -- a frame a call, the arguments as a list, a number a new
   value -- and Node's column says how far a machine of bytecodes
   written in C++ is from there: three to five times.

   reframe:
   A closure is a routine's address and the data it needs; a tree of
   them called one from the other is threaded code with a record at
   each address. Forth (Forth.mli) is the bare form: a word's body is
   the addresses of the words it is made of, and three lines go from
   one to the next. There the compiler is the programmer's (a colon
   definition); here it is this module, and the "addresses" are
   OCaml's closures. In ix the picture closes on itself: the host's
   compiler that Feeley and Lapalme count on (below) is mini-ml, so a
   JavaScript function ends, two compilers down, as arm code that
   mini-ml made of this file's closures.

   cs-history:
   SICP's fourth chapter does it to its Scheme evaluator in a section
   named for it, "Separating Syntactic Analysis from Execution"
   (Abelson and Sussman, second edition, 1996): analyze gives a
   procedure of the environment. Feeley and Lapalme made it a way to
   write compilers
   (Using Closures for Code Generation, Computer Languages, 1987): the
   target is closures of the language the compiler is written in, and
   the host's own compiler does the code generation.

   modern:
   No engine of a browser stops there. V8 compiles a function to
   bytecode for a register machine (Ignition), where a local name is a
   register's number, and the functions that run often to machine code
   that assumes what it has seen (their types, their shapes) and goes
   back to the bytecode when it was wrong. *)
(* ix: the author's mini-chrome's languages/javascript/eval/Js_compile.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* [body t f]: f's body compiled for the engine t: given a call's
 * frame and its this, what the call returns. Js_eval calls it by its
 * [compiler] reference, set to this function when the program starts *)
val body : Js_eval.t -> Js_ast.func -> Js_value.scope -> Js_value.value -> Js_value.value
