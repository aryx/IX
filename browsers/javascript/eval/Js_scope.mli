(* Scopes are where a program's names live while it runs. This module
   says how a name is found, in the simple way and in a fast one.

   A scope is a frame of names and the frame around it
   (Js_value.scope). The globals are at the top; under them is a
   function's call (its parameters and vars), and under that a block's
   let and const. A function value keeps the scope it was written in
   (a closure), and a call's frame goes under that one, not under the
   caller's. So which x a function means is read in its text, not in
   who calls it.

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
   the one around, up to the globals ([lookup]). There is nothing to
   prepare and nothing to keep true, and it is what the language's
   definition says. Its cost is that "total" above is hashed three
   times at each turn of the loop, and each call makes a table and
   fills it name by name, and so does each block.

   **The fast way**: each scope is an array of bindings, with their
   names beside it in the order they were declared ([Js_value.slots]).
   Each place in the program's text where a name is written remembers
   where it found the name the last time: how many scopes up, and
   which slot there ([Js_ast.place], in the copy of the tree that
   Js_quicken makes, where a Name is a Local). [find] goes straight
   there, and checks that the slot's name is the one asked. That is
   one comparison, most often of two addresses, because the lexer
   makes one string of a name written many times. If it is not the
   one asked (the first time, or when a name was declared since), the
   name is looked for as the simple way does, in arrays instead of
   tables, and the place is written again.

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
   does (Js_eval's with_subject). And a name that is not found is not
   remembered: it is looked for again each time (typeof of a library
   not loaded yet).

   There is one difference with the simple way, in a program that is a
   mistake: a name read in a block before the let that declares it
   there, and read again after it, by the same place in the text (a
   function called twice). The simple way gives the outer name, then
   the inner one; the fast way gives the outer one twice; JavaScript
   itself gives a ReferenceError (the "temporal dead zone").

   Past sixteen names, a scope has an index of them (a table from a
   name to its slot). That is for the globals, and for the one
   function that a bundler or js_of_ocaml wraps a whole program in,
   with thousands of names in one frame. A call's frame shares its
   function's array of names and its index with every other call
   (Js_ast.frame; Js_frame.opti makes the frame). So the arrays are
   never written past their end; a longer one is made instead.

   Here is what it bought, together with the rest of what is marked
   "opti:" in the engine (two numbers added without conversions, and
   an array's item read by its number: Js_operators.arithmetic_opti,
   Js_eval.item_opti). It was measured with mini-chrome's
   scripts/perf/Js_bench.exe on 2026-10-03, there and on its machine;
   ix has the code and not the bench:

                                    before    opti=off    now
     a loop, 3M turns               5,900 ms   2,330 ms  1,040 ms
     calls, 1M                      3,700      1,360       670
     properties, 1M                 2,440          -       440
     arrays, 1M                     2,990          -       390
     the Playground's menu, start   6,800          -     2,000
     the same, one frame              870          -       206

   ("before" is the engine of the day before. The simple way gained
   too, from what was simply removed: a scope for a block that
   declares nothing, and three names looked up at each call to know if
   the code is strict; a scope now says so itself, with [strict].)

   Where it stands: Js_eval asks this module at every name read or
   set, and at every block that declares a name; Js_frame makes a call's
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
   (Sussman and Steele, 1975) took Algol's rule, where the text
   decides; JavaScript took Scheme's rule in 1995. Remembering a place
   at the place of use is the inline cache of Deutsch and Schiffman's
   Smalltalk-80 (Efficient Implementation of the Smalltalk-80 System,
   POPL 1984), made for a method's lookup. It is the idea that Self
   and then V8 (2008) put under every property read.

   others:
   The textbook way is a pass over the tree before it runs, which
   gives each name its place once and for all (de Bruijn's indices,
   1972; Nystrom's Crafting Interpreters, "Resolving and Binding").
   Then there is no check when the program runs; but the pass has to
   know every way the language makes a scope, including with, eval
   and hoisting, and it has to be kept true to the evaluator. Here the
   pass before the run (Js_quicken) only makes room, and the evaluator
   itself fills it, a name at a time.

   modern:
   A real engine compiles: the tree becomes bytecode in which a local
   name is a register and an outer one is a slot of a context object
   (V8's Ignition), and the hot functions become machine code. No
   scope is made for a call whose names no closure keeps. *)
(* ix: copied from languages/javascript/eval/Js_scope.mli in the
 * author's mini-chrome, at its commit 8af888e (docs/plans/plan_browser.md) *)

open Js_value

(* the globals of an engine: tables if Mini_opti is off when it is
 * made, slots otherwise. The scopes under it are of the same kind. *)
val global : unit -> scope

(* a scope under another: a block's, a call's *)
val nested : scope -> scope

(* the same, for strict code: a module's, a class's, a function that
 * says "use strict" *)
val strict : scope -> scope

(* the scope of with (o) { }: o's properties are names in it *)
val with_subject : scope -> value -> scope

(* opti: makes a call's frame at once, from its names (shared, never
 * written), their index if they are many, and a binding for each *)
val frame : scope -> names:string array -> index:(string, int) Hashtbl.t option -> cells:binding array -> strict:bool -> scope

(* whether the scope is the fast kind *)
val slotted : scope -> bool

(* a binding that is nobody's, to fill an array with *)
val nothing : binding

(* [declare s x ~constant v] makes x a name of s, holding v. When x is
 * declared again, a new binding takes its place. *)
val declare : scope -> string -> constant:bool -> value -> unit

(* [share s x b] makes x in s the binding b itself, which another scope
 * has too (a module's import is the exporter's very binding) *)
val share : scope -> string -> binding -> unit

(* the scope's own binding of a name, not its parents' *)
val own : scope -> string -> binding option

(* the binding of a name seen from a scope: its own, or else the
 * nearest one around it, found by the name alone *)
val lookup : scope -> string -> binding option

(* the same, for a name written in the program: looked for where it
 * was last found (the place is written when it is not there) *)
val find : scope -> string -> Js_ast.place -> binding option

(* [find] for a scope of the fast kind, with no option made: it gives
 * [nothing] itself (==) when the name is nowhere *)
val at : scope -> string -> Js_ast.place -> binding

(* a for's next iteration: the same names in new bindings, holding the
 * same values *)
val copy : scope -> scope
