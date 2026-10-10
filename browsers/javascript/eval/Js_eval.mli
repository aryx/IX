(* Js_eval: a JavaScript program run, by walking its tree.

   cs-history:
   The language. Brendan Eich wrote the first JavaScript in ten days
   of May 1995, at Netscape, which wanted a language for the people
   who wrote pages, to go with Java for the people who wrote programs:
   it was to "look like Java", and under that skin Eich put what he
   admired -- Scheme's functions, first-class and closing over their
   variables, and Self's objects, with prototypes and no classes. It
   shipped in Navigator 2 (as LiveScript in the betas; renamed for
   marketing), Microsoft copied it as JScript (Internet Explorer 3,
   1996), and to keep the two alike it was standardized at Ecma:
   ECMA-262, "ECMAScript", 1997. Its editions are the tags of
   Js_ast.mli: ES3 (1999) the language of the first web applications;
   a fourth abandoned after years of dispute (2008); ES5 (2009); ES2015
   ("ES6": let, classes, arrows, promises, modules) and one a year
   since. The ten days show still -- in ==, in var's scope, in typeof
   null -- because nothing a page relies on can be taken back.

   modern:
   How it is run here is the simplest way: the tree is walked, each
   node's rule applied. An engine compiles the tree first -- Eich's
   own to a bytecode that it then interpreted, as SpiderMonkey, its
   descendant, still does to start with. What made JavaScript fast
   enough to write Gmail's successors in was the next step, compiling
   to machine code as the program runs: V8 (Lars Bak, Google, 2008,
   for Chrome), with Self's own techniques -- hidden classes, inline
   caches -- found again twenty years on. None of that
   is here: this is the language's meaning, not its speed.

   reframe:
   The ways to run a program, all of them in ix, from the nearest to
   the text to the nearest to the machine. The tree walked by
   recursion, the host's stack being the program's: here, and the
   shell's Eval. The same walk with the stack made data, a machine's
   state stepped in a loop, so that a program can be stopped in its
   middle and its continuation be a value: Scheme_eval's CESK machine
   and Scheme_secd's (what Js_coroutine has to borrow a thread for).
   The tree turned into closures once: Js_compile. Into addresses run
   one after the other, threaded code: Forth. Into bytecode for a
   machine with a stack: mini-pascal's P-machine, mini-smalltalk's
   interpreter of the Blue Book. Into the processor's instructions:
   mini-cc and mini-ml. JavaScript's engines went that whole road in
   fifteen years (the paragraph above); this one stays at its first
   two steps, where the language's rules can be read one a case.

   (mini-chrome's notes_javascript.md, sections 5 to 8.) Each kind of
   node has its rule: an expression's value from its children's, a
   statement's effect. What makes a language of it is three things:

   **Scopes.** A scope is a frame of names and the frame around it
   (Js_value.scope). let and const add a name to the current frame (a
   var to its function's, where it is from the call's start, undefined:
   Js_frame); a name is looked for in the current
   frame, then the one around it, up to the global one, else a
   ReferenceError. A block, a call and each iteration of a for make a
   new frame -- each iteration its own copy of the loop's let, so that
   functions made in the loop each keep their own i (the spec's
   CreatePerIterationEnvironment). Function declarations are defined
   first in their block ("hoisted"), so a function can be called above
   where it is written. How a scope keeps its names and how one is
   found, the simple way and the fast one, is Js_scope's.

   **Closures.** A function value keeps the frame it was *created* in;
   a call makes a frame for the parameters whose parent is that frame,
   not the caller's. So a function can use, and change, the variables
   of a call that has returned:

     function counter() { let n = 0; return () => { n = n + 1; return n } }
     const c = counter(); c(); c()      // 2: the n of counter's call, kept by c

   **Leaving.** A statement finishes normally or wants to leave: return
   (with a value), break, continue -- an [outcome], passed up by the
   blocks, caught by the loops and the calls. A thrown value (throw, or
   an error of the engine) is an OCaml exception (Js_value.Throw),
   because it crosses calls, the host's OCaml ones included (a callback
   throwing inside forEach).

   **Later.** An async function's call runs its body as a coroutine
   (Js_coroutine), up to its first await, and gives a promise of what
   it will return; await suspends the body until the promise awaited
   is settled. What promises have to do when they are settled is a
   queue of jobs (Js_promise), run to its end after each [run] and
   each [call]: when the script has returned, never in its middle.

   **Names that are not variables.** In "with (o) { ... }" a name that
   is a property of o is that property (a frame keeps the object:
   Js_value.scope's subject); and an object can be a Proxy, whose
   handler's traps are called where a property is read, set, tested or
   deleted. Both are how a library runs a template's expressions
   against a page's data and learns what they read.

   **this.** In o.f(), f runs with this bound to o; in f(), to the
   global object, as the language has done since 1995 (to undefined
   in a function that says "use strict", ES5's repair); an arrow has
   no this of its own, it keeps the one of where it was written
   -- why event handlers are written as arrows.

   The coercions of section 7 are here, over Js_value's conversions:
   + adds two numbers but concatenates if either side (as a primitive)
   is a string; - * / % convert both to numbers; < compares strings as
   strings, the rest as numbers; && and || give one of their operands,
   not a boolean. == converts before it compares (null == undefined,
   "1" == 1: Js_operators.loose_equal has the table), === does not.

   Where it stands. The engine is made by its host ([create_with]:
   where console.log writes, the seed, the clock), given the host's
   objects as globals ([define]), and then asked to run texts ([eval])
   and, later, to call the functions the scripts left with the host
   ([call]: an event's handler, a timer's):

     mini-node's CLI     a file, or a line typed    console only
     Browser_script      a page's <script>s         document, window,
                         then its events' handlers  timers, fetch, the
                         and timers' functions      modules' texts

   Under it: Js_parse for the text, Js_scope and Js_frame for the
   names, Js_value, Js_props and Js_operators for what a value is and
   does, Js_builtins and Js_globals for what is there before the
   first line, Js_promise and Js_coroutine for what runs later, and
   Js_compile, which it does not name (a reference the other sets).

   Reference: Allen Wirfs-Brock and Brendan Eich, "JavaScript: The
   First 20 Years" (HOPL IV, 2020), the history by those who made it;
   ECMA-262 (the language: section 9.1, environments; 10.2,
   functions); Gerald Sussman and Guy Steele, "Scheme: An Interpreter
   for Extended Lambda Calculus" (1975), closures; Self's paper, for
   the prototypes, is Js_props's.

   **Errors**, named as browsers name them, on the line of their
   statement: "ReferenceError: x is not defined", "TypeError: f is not
   a function", "TypeError: Cannot read properties of undefined
   (reading 'y')". And two a page must never do: recurse without end
   (RangeError: Maximum call stack size exceeded) or loop without end
   -- a page's script runs to its end before the page moves again, so
   [while (true) {}] would freeze the browser; after a budget of steps
   the engine stops it with an error, as browsers ask "A script on this
   page is busy: stop it?". *)
(* ix: the author's mini-chrome's languages/javascript/eval/Js_eval.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* an interpreter: its global scope, what console.log prints to *)
type t

(* [create ?log ?seed ?now ()]: the built-ins defined (Js_builtins);
 * console writes to [log] (nothing by default), Math.random from [seed]
 * (1), Date's clock [now] (milliseconds since 1970: 0) *)
val create_with : (string -> unit) -> int -> (unit -> float) -> t

(* the same: nothing logged, the seed 1, the clock at 0
 * (ix: create's three were optional arguments) *)
val create : unit -> t

(* a mistake, as a console shows it: "ReferenceError: x is not
 * defined", on its line; an uncaught throw of any value, "Uncaught "
 * and it *)
type error = { line : int; message : string }

(* what a thrown value is as an error, on the line now running *)
val error_of : t -> Js_value.value -> error

(* [run t program]: its statements run in the global scope; the value
 * of the last expression statement run (undefined if none): what a
 * console prints after a line typed *)
val run : t -> Js_ast.program -> (Js_value.value, error) result

(* a text's program if it was read already, elsewhere (Js_module's
 * memo, filled by [Js_module.ahead] where the text was fetched):
 * [eval] asks before it parses *)
val read_ahead : (string -> (Js_ast.program, Js_parse.error) result option) ref

(* parse, then run *)
val eval : t -> string -> (Js_value.value, error) result

(* [call t f this args]: the host calling a script's function (an event
 * handler, a timer's) *)
val call : t -> Js_value.value -> this:Js_value.value -> Js_value.value list -> (Js_value.value, error) result

(* the same two from a host function that a script called (require, an
 * event dispatched by a script): in the run going on -- its budget,
 * its jobs run after it, not now -- and a mistake is thrown
 * (Js_value.Throw), a text that does not parse as a SyntaxError *)
val eval_in_run : t -> string -> Js_value.value
val call_in_run : t -> Js_value.value -> this:Js_value.value -> Js_value.value list -> Js_value.value

(* a property read, through getters, prototypes and proxies; a new
 * promise with its resolve and reject (Js_promise.make): for a host
 * whose answer comes later (fetch) *)
val get : t -> Js_value.value -> string -> Js_value.value
val promise : t -> Js_value.value * (Js_value.value -> unit) * (Js_value.value -> unit)

(* the items of what can be gone through (an array, a Set, a generator) *)
val items : t -> Js_value.value -> Js_value.value list

(* a global, read and defined (the host's: document, and window's) *)
val global : t -> string -> Js_value.value option
val define : t -> string -> Js_value.value -> unit

(* [steps] (10 million by default): the budget of a run or a call *)
val set_budget : t -> int -> unit

(* a run's or a job's time at most, by the clock (none by default):
 * for a host whose scripts may rightly run long, a browser's page,
 * which gives steps without count and a minute *)
val set_seconds : t -> float -> unit

(* how long the run being made has lasted, in seconds (0 between two) *)
val running_for : t -> float

(*****************************************************************************)
(* {1 What modules ask} *)
(*****************************************************************************)

(* Js_module's, which is after this one: a module is a program run in
 * a scope of its own, and the rest of what a module is -- where its
 * text comes from, what it exports, who imports it -- is told there. *)

(* a scope under the globals for the module of that address
 * (import.meta.url, and what its import() is relative to) *)
val module_scope : t -> url:string -> Js_value.scope

(* a module's statements run in its scope, its var's and functions
 * hoisted; its import lines do nothing (the names are bound before),
 * its exports are their declarations, the default kept as the name
 * "*default*". In a run: throws *)
val exec_module : t -> Js_value.scope -> Js_ast.program -> unit

(* a module's var's and function declarations, in its scope before it
 * runs: what a module in a circle with it finds *)
val hoist_module : Js_value.scope -> Js_ast.program -> unit

(* what import("m") does: given the address of the module asking and
 * the text asked for, a promise of the module's names *)
val set_importer : t -> (base:string -> string -> Js_value.value) -> unit

(* [protect t f]: f as a run -- its budget, its throws caught, the
 * promises' jobs after it *)
val protect : t -> (unit -> Js_value.value) -> (Js_value.value, error) result

(* the names a pattern binds: [a, {b}] binds a and b *)
val names_of : Js_ast.pattern -> string list

(*****************************************************************************)
(* {1 What the compiler asks} *)
(*****************************************************************************)

(* Js_compile's, which is after this one: a function's body made
 * closures, calling back here for what it does not compile and for
 * what a value is asked (a property, a call). In a run: these throw. *)

(* how a statement ended *)
type outcome = Normal | Return of Js_value.value | Break of string option | Continue of string option

(* an expression's value, a statement's effect, in a scope and with a this *)
val eval_expr : t -> Js_value.scope -> Js_value.value -> Js_ast.expr -> Js_value.value
val exec : t -> Js_value.scope -> Js_value.value -> Js_ast.stmt -> outcome

(* a statement begun: its line kept for an error, a step of the budget taken *)
val step : t -> int -> unit

(* a block's function declarations made, first; whether a block
 * declares a name of its own, and so needs a scope *)
val declare_functions : nested:bool -> Js_value.scope -> Js_value.value -> Js_ast.stmt list -> unit
val declares : Js_ast.stmt list -> bool

(* o.k = v; o[k] and o[k] = v, k a value; target = v, any target; a
 * function's value, made in a scope; "o.m", what an error names *)
val put : t -> Js_value.value -> string -> Js_value.value -> unit
val item : t -> Js_value.value -> Js_value.value -> Js_value.value
val put_item : t -> Js_value.value -> Js_value.value -> Js_value.value -> unit
val assign : t -> Js_value.scope -> Js_value.value -> Js_ast.expr -> Js_value.value -> unit
val closure : Js_value.scope -> Js_value.value -> Js_ast.func -> Js_value.value
val describe : Js_ast.expr -> string

(* the built-in prototypes (an array's methods are Array.prototype's);
 * a instanceof f *)
val protos : t -> Js_builtins.protos
val instance_of : t -> Js_value.value -> Js_value.value -> bool

(* who compiles a function's body: set by Js_compile, read at a
 * function's first call when Mini_opti.compiled *)
val compiler : (t -> Js_ast.func -> Js_value.scope -> Js_value.value -> Js_value.value) option ref
