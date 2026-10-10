(* Scopes: where a program's names live while it runs, and how a name
   is found -- the simple way, and a fast one.

   A scope is a frame of names and the frame around it
   (Js_value.scope): the globals, under them a function's call (its
   parameters and var's), under that a block's let and const. A
   function value keeps the scope it was written in (a closure), and
   a call's frame goes under that one, not under the caller's: which
   x a function means is read in its text, not in who calls it.

     var total = 0;
     function add(n) {
       for (var i = 0; i < n; i++) { total = total + i }
     }
     add(4); add(3);

     the globals    total  add  ...        <- 2 scopes up from the body
       add's call   arguments  i  n         <- 1 up
         the body   (nothing of its own)    <- where "total = total + i" runs

   **The simple way** (opti=off): each scope has a table of its names
   (a Hashtbl), and a name is looked for in the nearest scope, then in
   the one around, up to the globals: [lookup]. Nothing to prepare,
   nothing to keep true, and it is what the language's definition
   says. Its cost: "total" above is hashed three times at each turn
   of the loop, each call makes a table and fills it name by name, and
   so does each block.

   **The fast way**: each scope is an array of bindings, their names
   beside in the order they were declared ([Js_value.slots]), and each
   place in the program's text where a name is written remembers where
   it found it the last time: how many scopes up, and which slot there
   ([Js_ast.place], in the copy of the tree Js_quicken makes: a Name
   there is a Local). [find] goes straight there, and
   checks that the slot's name is the one asked -- one comparison,
   most often of two addresses, the lexer making one string of a name
   written many times. If it is not (the first time; a name declared
   since), the name is looked for as the simple way does, in arrays
   in place of tables, and the place written again.

     total   at "total = total + i":   { hops = 2; slot = its number among the globals }
     i                                 { hops = 1; slot = 1 }    (after arguments)

   Why it can be trusted: the scopes between a place in the text and
   the one that has its name are always the same ones, made by the
   same lines of the program (a block, a call of the function it is
   in, the function's own scope...), so the count of them is a fact of
   the text. What changes from a run to the next is which slot a name
   has in a scope whose declarations depend on the run (a switch
   entered by another case), and the check sees that. Inside a with
   (obj) { }, the object is asked first each time, as the simple way
   does (Js_eval's with_subject); and a name not found is not
   remembered so: it is looked for again each time (typeof of a
   library not loaded yet).

   One difference with the simple way, in a program that is a mistake:
   a name read in a block before the let that declares it there, and
   read again after, by the same place in the text (a function
   called twice). The simple way gives the outer name then the inner;
   the fast way the outer twice; JavaScript itself, a ReferenceError
   (the "temporal dead zone").

   Past sixteen names a scope has an index of them (a table from a
   name to its slot): the globals, and the one function a bundler or
   js_of_ocaml wraps a whole program in, thousands of names in one
   frame. A call's frame shares its function's array of names and its
   index with every other call (Js_ast.frame; Js_frame.opti makes the
   frame): the arrays are never written past their end, a longer
   one is made.

   What it bought, with what else is marked "opti:" in the engine
   (two numbers added without conversions, an array's item by its
   number: Js_operators.arithmetic_opti, Js_eval.item_opti), on
   mini-chrome's scripts/perf/Js_bench.exe, 2026-10-03 (measured
   there, on its machine; ix has the code and not the bench):

                                    before    opti=off    now
     a loop, 3M turns               5,900 ms   2,330 ms  1,040 ms
     calls, 1M                      3,700      1,360       670
     properties, 1M                 2,440          -       440
     arrays, 1M                     2,990          -       390
     the Playground's menu, start   6,800          -     2,000
     the same, one frame              870          -       206

   ("before" is the engine of the day before; the simple way gained too
   from what was simply removed: a scope for a block that declares
   nothing, three names looked up at each call to know if the code is
   strict -- a scope now says so, [strict].)

   Where it stands: Js_eval asks this module at every name read or
   set and at every block that declares; Js_frame makes a call's
   scope; Js_value has the type, since a closure holds its scope and
   a value may be a closure. The two ideas of the paragraph below can
   be read in ix under their first names: Landin's machine is
   Scheme_secd, whose E register is the scope here, and the inline
   cache is told in St_interp.mli, mini-smalltalk's interpreter, after
   the Blue Book's method cache that it replaced.

   cs-history:
   A function with the scope it was written in is Landin's closure
   (The Mechanical Evaluation of Expressions, 1964: the SECD machine,
   whose E is this module's scope). Lisp looked a name up in the
   caller's frames for fifteen years (dynamic scope) before Scheme
   (Sussman and Steele, 1975) took Algol's rule, the text's; JavaScript
   took Scheme's in 1995. A place remembered at the place of use is
   the inline cache of Deutsch and Schiffman's Smalltalk-80 (Efficient
   Implementation of the Smalltalk-80 System, POPL 1984), made
   for a method's lookup, and the idea Self and then V8 (2008) put
   under every property read.

   others:
   The textbook way is a pass over the tree before it runs, which
   gives each name its place once and for all (de Bruijn's indices,
   1972; Nystrom's Crafting Interpreters, "Resolving and Binding").
   No check when the program runs; but the pass has to know every way
   the language makes a scope, with, eval and hoisting among them, and
   to be kept true to the evaluator. Here the pass before the run
   (Js_quicken) only makes room, and the evaluator itself fills it, a
   name at a time.

   modern:
   A real engine compiles: the tree becomes bytecode in which a local
   name is a register and an outer one a slot of a context object
   (V8's Ignition), and the hot functions machine code. No scope is
   made for a call whose names no closure keeps. *)
(* ix: the author's mini-chrome's languages/javascript/eval/Js_scope.mli (its 8af888e) (docs/plans/plan_browser.md) *)

open Js_value

(* the globals of an engine: tables if Mini_opti is off when it is
 * made, slots else; the scopes under it are of its kind *)
val global : unit -> scope

(* a scope under another: a block's, a call's *)
val nested : scope -> scope

(* the same, of strict code: a module's, a class's, a function that
 * says "use strict" *)
val strict : scope -> scope

(* the scope of with (o) { }: o's properties are names in it *)
val with_subject : scope -> value -> scope

(* opti: a call's frame made at once: its names (shared, not written),
 * their index if they are many, a binding for each *)
val frame : scope -> names:string array -> index:(string, int) Hashtbl.t option -> cells:binding array -> strict:bool -> scope

(* whether the scope is the fast kind *)
val slotted : scope -> bool

(* a binding that is nobody's, to fill an array with *)
val nothing : binding

(* [declare s x ~constant v]: x is a name of s, holding v; declared
 * again, a new binding in its place *)
val declare : scope -> string -> constant:bool -> value -> unit

(* [share s x b]: x in s is the binding b itself, which another scope
 * has too (a module's import is the exporter's very binding) *)
val share : scope -> string -> binding -> unit

(* the scope's own binding of a name, not its parents' *)
val own : scope -> string -> binding option

(* the binding of a name seen from a scope: its own, else the nearest
 * around; by the name alone *)
val lookup : scope -> string -> binding option

(* the same, for a name written in the program: looked for where it
 * was last found (the place is written when it is not there) *)
val find : scope -> string -> Js_ast.place -> binding option

(* [find] for a scope of the fast kind, with no option made: [nothing]
 * itself (==) when the name is nowhere *)
val at : scope -> string -> Js_ast.place -> binding

(* a for's next iteration: the same names in new bindings, holding the
 * same values *)
val copy : scope -> scope
