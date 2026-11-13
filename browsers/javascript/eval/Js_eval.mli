(* Js_eval runs a JavaScript program by walking its tree.

   cs-history:
   First, the language. Brendan Eich wrote the first JavaScript in ten days
   of May 1995, at Netscape, which wanted a language for the people
   who wrote pages, to go with Java for the people who wrote programs:
   it was to "look like Java", and under that skin Eich put what he
   admired -- Scheme's functions, first-class and closing over their
   variables, and Self's objects, with prototypes and no classes. It
   shipped in Navigator 2 (called LiveScript in the betas, and renamed
   for marketing). Microsoft copied it as JScript (Internet Explorer 3,
   1996), and to keep the two alike it was standardized at Ecma:
   ECMA-262, "ECMAScript", 1997. Its editions are the tags of
   Js_ast.mli: ES3 (1999), the language of the first web applications;
   a fourth, abandoned after years of dispute (2008); ES5 (2009);
   ES2015 ("ES6": let, classes, arrows, promises, modules); and one
   edition a year since then. The ten days still show (in ==, in var's
   scope, in typeof null), because nothing a page relies on can be
   taken back.

   modern:
   It is run here in the simplest way: the tree is walked, and each
   node's rule is applied. An engine compiles the tree first. Eich's
   own compiled it to a bytecode that it then interpreted, as
   SpiderMonkey, its descendant, still does to start with. What made
   JavaScript fast enough to write Gmail's successors in was the next
   step, compiling to machine code as the program runs. That was V8
   (Lars Bak, Google, 2008, for Chrome), which found Self's own
   techniques (hidden classes, inline caches) again twenty years on.
   None of that is here: this module is about the language's meaning,
   not its speed.

   reframe:
   Here are the ways to run a program, all of them in ix, from the
   nearest to the text to the nearest to the machine. The tree can be
   walked by recursion, the host's stack being the program's: that is
   this module, and the shell's Eval. The same walk can be made with
   the stack as data, a machine's state stepped in a loop, so that a
   program can be stopped in its middle and its continuation can be a
   value: that is Scheme_eval's CESK machine and Scheme_secd's (it is
   what Js_coroutine has to borrow a thread for). The tree can be
   turned into closures once: Js_compile. It can be turned into
   addresses run one after the other, threaded code: Forth. It can be
   turned into bytecode for a machine with a stack: mini-pascal's
   P-machine, and mini-smalltalk's interpreter of the Blue Book. Or it
   can be turned into the processor's instructions: mini-cc and
   mini-ml. JavaScript's engines went that whole road in fifteen years
   (the paragraph above); this one stays at the first two steps, where
   the language's rules can be read one case at a time.

   (See mini-chrome's notes_javascript.md, sections 5 to 8.) Each kind
   of node has its rule: an expression's rule computes its value from
   its children's values, and a statement's rule has its effect. What
   makes a language of it is six things:

   **Scopes.** A scope is a frame of names and the frame around it
   (Js_value.scope). let and const add a name to the current frame. A
   var adds it to its function's frame, where it is there from the
   call's start, undefined (Js_frame). A name is looked for in the
   current frame, then in the one around it, up to the global one; if
   it is not found, that is a ReferenceError. A block, a call and each
   iteration of a for make a new frame. Each iteration has its own
   copy of the loop's let, so that functions made in the loop each
   keep their own i (the spec's CreatePerIterationEnvironment).
   Function declarations are defined first in their block ("hoisted"),
   so a function can be called above where it is written. How a scope
   keeps its names and how a name is found, the simple way and the
   fast one, is told in Js_scope.

   **Closures.** A function value keeps the frame it was *created* in;
   a call makes a frame for the parameters whose parent is that frame,
   not the caller's. So a function can use, and change, the variables
   of a call that has returned:

     function counter() { let n = 0; return () => { n = n + 1; return n } }
     const c = counter(); c(); c()      // 2: the n of counter's call, kept by c

   **Leaving.** A statement either finishes normally or wants to leave,
   with return (and a value), break or continue. That is an [outcome],
   which the blocks pass up and the loops and the calls catch. A
   thrown value (throw, or an error of the engine) is an OCaml
   exception (Js_value.Throw), because it crosses calls, including the
   host's OCaml ones (a callback throwing inside forEach).

   **Later.** An async function's call runs its body as a coroutine
   (Js_coroutine), up to its first await, and gives a promise of what
   it will return; await suspends the body until the promise awaited
   is settled. What promises have to do when they are settled is kept
   in a queue of jobs (Js_promise), which is run to its end after each
   [run] and each [call]: when the script has returned, never in its
   middle.

   **Names that are not variables.** In "with (o) { ... }", a name that
   is a property of o means that property (a frame keeps the object,
   in Js_value.scope's subject). That is how a library runs a
   template's expressions against a page's data. (This is not a Proxy,
   whose traps a framework's reactivity needs; Proxy is not here:
   plan_browser.md, C.)

   **this.** In o.f(), f runs with this bound to o. In f(), this is
   bound to the global object, as the language has done since 1995
   (or to undefined in a function that says "use strict", which is
   ES5's repair). An arrow has no this of its own; it keeps the one of
   the place where it was written, which is why event handlers are
   written as arrows.

   The coercions of section 7 are here, built over Js_value's
   conversions. + adds two numbers, but concatenates if either side
   (as a primitive) is a string; - * / % convert both sides to
   numbers; < compares strings as strings and the rest as numbers; &&
   and || give one of their operands, not a boolean. == converts
   before it compares (null == undefined, "1" == 1;
   Js_operators.loose_equal has the table), and === does not.

   Where it stands: the engine is made by its host ([create_with],
   which says where console.log writes, the seed and the clock). The
   host gives it its objects as globals ([define]), then asks it to
   run texts ([eval]) and, later, to call the functions the scripts
   left with the host ([call]: an event's handler, a timer's
   function):

     mini-node's CLI     a file, or a line typed    console only
     Browser_script      a page's <script>s         document, window,
                         then its events' handlers  timers, fetch, the
                         and timers' functions      modules' texts

   Under it are Js_parse for the text, Js_scope and Js_frame for the
   names, Js_value, Js_props and Js_operators for what a value is and
   does, Js_builtins and Js_globals for what is there before the
   first line, Js_promise and Js_coroutine for what runs later, and
   Js_compile, which it does not name (Js_compile sets a reference
   here, [compiler]).

   Reference: Allen Wirfs-Brock and Brendan Eich, "JavaScript: The
   First 20 Years" (HOPL IV, 2020), the history by those who made it;
   ECMA-262 (the language: section 9.1, environments; 10.2,
   functions); Gerald Sussman and Guy Steele, "Scheme: An Interpreter
   for Extended Lambda Calculus" (1975), for closures. Self's paper,
   for the prototypes, is cited in Js_props.mli.

   **Errors** are named as browsers name them, on the line of their
   statement: "ReferenceError: x is not defined", "TypeError: f is not
   a function", "TypeError: Cannot read properties of undefined
   (reading 'y')". And there are two things a page must never do:
   recurse without end (RangeError: Maximum call stack size exceeded)
   or loop without end. A page's script runs to its end before the
   page moves again, so [while (true) {}] would freeze the browser.
   After a budget of steps, the engine stops it with an error, as
   browsers ask "A script on this page is busy: stop it?". *)
(* ix: copied from languages/javascript/eval/Js_eval.mli in the
 * author's mini-chrome, at its commit 8af888e (docs/plans/plan_browser.md) *)

(* an interpreter, with its global scope and what console.log prints to *)
type t

(* [create_with log seed now] defines the built-ins (Js_builtins).
 * console writes to [log], Math.random starts from [seed], and Date's
 * clock is [now] (milliseconds since 1970). *)
val create_with : (string -> unit) -> int -> (unit -> float) -> t

(* the same, with nothing logged, the seed 1 and the clock at 0
 * (ix: in mini-chrome, create's three arguments are optional) *)
val create : unit -> t

(* a mistake, as a console shows it: "ReferenceError: x is not
 * defined", on its line. An uncaught throw of any value is shown as
 * "Uncaught " followed by the value. *)
type error = { line : int; message : string }

(* what a thrown value is as an error, on the line now running *)
val error_of : t -> Js_value.value -> error

(* [run t program] runs its statements in the global scope. It gives
 * the value of the last expression statement run (undefined if there
 * is none), which is what a console prints after a line is typed. *)
val run : t -> Js_ast.program -> (Js_value.value, error) result

(* parse, then run *)
val eval : t -> string -> (Js_value.value, error) result

(* the same for a page's script, which is read as far as it can be
 * (Js_parse.parse_page): each mistake passed over is given to
 * [skipped], and the rest is run. The second one runs it in the run
 * going on (see [eval_in_run] below). *)
val eval_page : t -> skipped:(Js_parse.error -> unit) -> string -> (Js_value.value, error) result
val eval_page_in_run : t -> skipped:(Js_parse.error -> unit) -> string -> Js_value.value

(* [call t f this args] is the host calling a script's function (an
 * event handler, a timer's function) *)
val call : t -> Js_value.value -> this:Js_value.value -> Js_value.value list -> (Js_value.value, error) result

(* the same two, for a host function that a script called (require,
 * an event dispatched by a script). They run in the run going on:
 * they use its budget, and their jobs run after it, not now. A
 * mistake is thrown (Js_value.Throw), and a text that does not parse
 * is thrown as a SyntaxError. *)
val eval_in_run : t -> string -> Js_value.value
val call_in_run : t -> Js_value.value -> this:Js_value.value -> Js_value.value list -> Js_value.value

(* [get] reads a property, through getters and prototypes.
 * [promise] makes a new promise with its resolve and reject
 * (Js_promise.make), for a host whose answer comes later (fetch). *)
val get : t -> Js_value.value -> string -> Js_value.value
val promise : t -> Js_value.value * (Js_value.value -> unit) * (Js_value.value -> unit)

(* the items of what can be gone through (an array, a Set, a generator) *)
val items : t -> Js_value.value -> Js_value.value list

(* [global] reads a global and [define] defines one (the host's
 * globals: document, and window's) *)
val global : t -> string -> Js_value.value option
val define : t -> string -> Js_value.value -> unit

(* [set_budget t steps] sets the budget of a run or a call (10 million
 * steps by default) *)
val set_budget : t -> int -> unit

(* the most time a run or a job may take, by the clock (no limit by
 * default). It is for a host whose scripts may rightly run long, such
 * as a browser's page, which gives steps without count and a
 * minute. *)
val set_seconds : t -> float -> unit

(* how long the run being made has lasted, in seconds (0 between two) *)
val running_for : t -> float

(*****************************************************************************)
(* {1 What the compiler asks} *)
(*****************************************************************************)

(* These are for Js_compile, which comes after this module: it makes a
 * function's body into closures, and calls back here for what it does
 * not compile and for what is asked of a value (a property, a call).
 * In a run, these throw. *)

(* how a statement ended *)
type outcome = Normal | Return of Js_value.value | Break of string option | Continue of string option

(* [eval_expr] gives an expression's value and [exec] has a statement's
 * effect, in a scope and with a this *)
val eval_expr : t -> Js_value.scope -> Js_value.value -> Js_ast.expr -> Js_value.value
val exec : t -> Js_value.scope -> Js_value.value -> Js_ast.stmt -> outcome

(* called when a statement begins: it keeps the line for an error and
 * takes a step of the budget *)
val step : t -> int -> unit

(* [declare_functions] makes a block's function declarations, first.
 * [declares] says whether a block declares a name of its own, and so
 * needs a scope. *)
val declare_functions : nested:bool -> Js_value.scope -> Js_value.value -> Js_ast.stmt list -> unit
val declares : Js_ast.stmt list -> bool

(* [put] is o.k = v; [item] and [put_item] are o[k] and o[k] = v, where
 * k is a value; [assign] is target = v, for any target; [closure] makes
 * a function's value in a scope; [describe] gives "o.m", what an error
 * names *)
val put : t -> Js_value.value -> string -> Js_value.value -> unit
val item : t -> Js_value.value -> Js_value.value -> Js_value.value
val put_item : t -> Js_value.value -> Js_value.value -> Js_value.value -> unit
val assign : t -> Js_value.scope -> Js_value.value -> Js_ast.expr -> Js_value.value -> unit
val closure : Js_value.scope -> Js_value.value -> Js_ast.func -> Js_value.value
val describe : Js_ast.expr -> string

(* [host_missing fn self f] says whether the call f(...) is of a method
 * that a host object does not have ([fn] is undefined and [self] is a
 * host's object). Such a call is told to Js_value.missing and does
 * nothing, giving undefined, where a script's own object would throw.
 * Js_compile's calls do the same. *)
val host_missing : Js_value.value -> Js_value.value -> Js_ast.expr -> bool

(* When it is true (the default), [host_missing] works as said above,
 * with a warning in the console (Js_value.say) once for each name.
 * When it is false (mini-netscape's strict=on), such a call throws its
 * TypeError, as before. *)
val lenient : bool ref

(* [protos] gives the built-in prototypes (an array's methods are
 * Array.prototype's); [instance_of] is a instanceof f *)
val protos : t -> Js_builtins.protos
val instance_of : t -> Js_value.value -> Js_value.value -> bool

(* who compiles a function's body. Js_compile sets it, and it is read
 * at a function's first call when Mini_opti.compiled is on. *)
val compiler : (t -> Js_ast.func -> Js_value.scope -> Js_value.value -> Js_value.value) option ref

(* who gives a tree its places, for a program and for a function.
 * Js_quicken (opti/) sets it, and it is read when a program is run in
 * a scope of slots. *)
val quickener : ((Js_ast.program -> Js_ast.program) * (Js_ast.func -> Js_ast.func)) option ref
