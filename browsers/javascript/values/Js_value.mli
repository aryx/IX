(* Js_value defines JavaScript's values, and how it converts one into
   another.

   (See mini-chrome's notes_javascript.md, sections 4 and 7.) There are
   seven kinds, plus symbol (a value of its own: see Js_globals.mli),
   and minus bigint (10n is the number 10: see Js_lexer):

   cs-history:
   The kinds are those of 1995, and their oddities came with them. A
   number is a float, which was the only kind of number until BigInt
   (2020): the first engine had integers inside, but the language never
   showed them. typeof null is "object" because in that engine a value
   was a tagged word, the tag 0 meant an object, and null was the zero
   pointer. This was a bug of the first week; its repair was proposed,
   and refused, because pages test for it. And the conversions (+ with
   a string concatenates, and == converts before comparing) were asked
   of Brendan Eich by the first users, who wanted "1" == 1 to be true
   for the text of a form's field; by his own account he regrets
   granting it. === (JavaScript 1.3, 1998; ES3, 1999) is the comparison
   without them.

     undefined  null  boolean  number (a float: 1 is 1.0)  string  object  function

   An **object** is a mutable table from names to values, which keeps
   its keys in the order they were added. An **array** is an object
   whose items are in a growable OCaml array, and [length] and indexing
   work on that array directly; engines do this too, behind the same
   appearance. A **function** is an object holding either a closure
   (its parameters, its body, and the scope it was created in:
   [scope]) or an OCaml function (a host function, such as console.log
   and the browser's functions). Objects are compared, passed and
   stored by reference: [{} === {}] is false.

   A **host object** belongs to the browser, such as document or an
   element. Its properties are OCaml functions that read and change the
   page (Js_eval calls [get] and [set] where it would otherwise look in
   the table).

   A string is an OCaml string in UTF-8, like the rest of the
   browser's text, and its [length] and indexes count its bytes
   ("é".length is 2, where JavaScript, counting UTF-16 units, says 1).
   Js_string's interface tells why.

   How the types hold one another ([value], [obj], [kind] below):

     value   Undefined | Null | Bool | Number | String | Rope | Symbol
               | Object of obj
     obj     props   its own properties, a list, the newest first
             proto   another obj, or none: where a property that it
                     does not have is looked for next (Js_props)
             kind    Plain | Array (its items, apart from props)
                     | Closure (a func of Js_ast, and the scope it was
                       written in)
                     | Host_function (an OCaml function)
                     | Host_object (a page's element) | Regexp
                     | Accessor

   So a function is an object with a kind, which is why f.x = 1 works,
   and why typeof must look at the kind to say "function". A scope
   (Js_scope's, whose type is here because a closure holds one) can be
   reached from any function value. Finding what a closure keeps alive
   is the job of OCaml's collector, and the engine has no collector of
   its own.

   A long string made by [+] is a **rope**: the two pieces are kept as
   they are, and written end to end only when the text is first read.
   Otherwise, a script that builds a text by adding to it (s += c, ten
   thousand times) would copy all it has at each addition, which is the
   square of the text's length in all.

   cs-history:
   Ropes come from Boehm, Atkinson and Plass, in Xerox PARC's Cedar: a
   string is a tree of pieces, so that joining two strings is one small
   node whatever their lengths ("Ropes: an Alternative to Strings",
   Software: Practice and Experience, 1995).

   modern:
   Every JavaScript engine has ropes, for this very loop: V8's
   ConsString and SpiderMonkey's JSRope, which are flattened in place
   the first time the characters are asked for. Here a rope is kept out
   of OCaml's sight rather than taught to all of the code: it lives in
   a script's variables, and whatever is stored in an object or given
   to one of our functions is made a String first ([flat]).

   **Conversions** are JavaScript's, which convert rather than refuse:
   [to_string], [to_number], [truthy] (false, 0, NaN, "", null and
   undefined are false; everything else is true, "0" and [] included),
   and [to_primitive] (an array gives its items joined with commas, and
   an object gives "[object Object]"). Section 7's table is Js_eval's
   [+], which is built on them (Js_operators).

   others:
   One type with a constructor for each kind is how an interpreter
   written in ML has its values, and OCaml's own tag does the work: a
   match is typeof. An engine in C packs the same in a machine word.
   The first engine's tagged word is told above. Today's engines use
   the floats themselves: of the 2^64 patterns of a double, about 2^53
   are NaNs, and arithmetic makes only one of them, which leaves room
   for a pointer and a tag in the others ("NaN boxing", in SpiderMonkey
   and JavaScriptCore). Or they keep small integers apart from pointers
   by a low bit (V8's Smi), as OCaml does for its int. Here a Number is
   a float in a box, allocated at each addition: the last lines of
   Js_compile.mli say what that costs.

   Reference: ECMA-262, section 6.1 (the language's types) and 7.1
   (the conversions: ToPrimitive, ToNumber, ToString, ToBoolean);
   Hans Boehm, Russ Atkinson and Michael Plass, "Ropes: an Alternative
   to Strings" (Software: Practice and Experience, 1995). *)
(* ix: copied from languages/javascript/values/Js_value.mli in the
 * author's mini-chrome, at its commit 8af888e (docs/plans/plan_browser.md) *)

type value =
  | Undefined
  | Null
  | Bool of bool
  | Number of float
  | String of string
  (* a long string not yet written out: two pieces joined by +, which
   * are put end to end when the string is first read ([flatten]). It
   * lives where a script keeps what it is computing (a variable, or an
   * argument of one of the script's functions), and it is made a
   * String wherever a value is stored or given to OCaml ([flat]): a
   * property, an array, a host function. So only the evaluator meets
   * one. *)
  | Rope of rope
  (* a symbol (ES2015): a unique value, usable as a property's key. It
   * holds that key, "@@7:description", or a well-known symbol's key,
   * "@@iterator": a string that no script writes *)
  | Symbol of string
  | Object of obj

and rope = { mutable pieces : pieces; size : int; (* its bytes *) units : int (* its length, as a script counts it: Js_string *) }
and pieces = Flat of string | Cat of rope * rope

and obj = {
  id : int; (* for printing cycles and for tests; identity is (==) *)
  mutable props : (string * value ref) list; (* the newest first: the keys in their order, reversed *)
  kind : kind;
  mutable proto : obj option; (* its prototype, where a property it does not have is looked for next *)
  mutable lookup : lookup option; (* its properties by their key, when they are many (Js_value's find) *)
  (* its own keys that do not show (not enumerable): a class's methods,
   * and what Object.defineProperty made without saying enumerable.
   * They are read and written like the others, but for-in,
   * Object.keys, a spread and JSON pass over them. *)
  mutable hidden : string list;
}

(* an object's properties in a table. It is good while the object's
 * list is the one the table was made from (==). Code that writes the
 * list itself, such as a delete, makes it stale without a word. *)
and lookup = { table : (string, value ref) Hashtbl.t; mutable of_props : (string * value ref) list }

and kind =
  | Plain
  | Array of items
  | Closure of closure
  | Host_function of string * (this:value -> value list -> value) (* its name, and the function *)
  | Host_object of host
  | Regexp of Js_regexp.t (* a regular expression (its lastIndex is a property) *)
  (* not an object that a script sees, but what a property is when it
   * has a getter and a setter ({ get k() { } }, Object.defineProperty):
   * the two functions, with undefined for the one it does not have.
   * Reading the property calls the first, and assigning to it calls
   * the second (Js_eval). *)
  | Accessor of value * value

(* an object whose properties are the host's functions: reading one
 * calls [get], and writing one calls [set] (the spec's getters and
 * setters). An example is a page's element, whose textContent is its
 * tree's text, not a stored value. [show] is how the console shows
 * it. *)
and host = { class_name : string; get : string -> value; set : string -> value -> unit; show : unit -> string }

and items = { mutable elements : value array; mutable length : int; mutable holes : int (* its first items never given (new Array(3)): map and forEach skip them while they are still undefined *) }

and closure = { func : Js_ast.func; scope : scope; this : value option (* an arrow's this, captured *) }

(* a frame of names, and the frame around it. [subject] is the object
 * of a with (obj) { }: a name that is a property of it is that
 * property. [in_with] says whether this frame or one around it has a
 * subject (if not, no frame is asked). [strict] says that the code
 * here is in strict mode ("use strict", a module, a class). *)
and scope = { vars : vars; parent : scope option; subject : value option; in_with : bool; strict : bool }

(* a scope's names. They are either in a table, the simple way, or
 * (an opti) in an array of bindings in the order they were declared.
 * Then their names are beside them (the first [used] of each), and
 * when they are many there is an index of the first [fixed] of them,
 * which is never written once made (Js_scope). *)
and vars = Table of (string, binding) Hashtbl.t | Slots of slots
and slots = { mutable names : string array; mutable cells : binding array; mutable used : int; mutable index : (string, int) Hashtbl.t option; mutable fixed : int }
and binding = { mutable value : value; constant : bool }

(* a JavaScript exception, thrown by [throw] or by the engine. It holds
 * any value, usually an error object. *)
exception Throw of value

(* opti: a function's body compiled. Given the call's frame and its
 * this, it returns what the call returns (Js_compile makes it, and
 * Js_eval calls it). *)
exception Compiled of (scope -> value -> value)

(*****************************************************************************)
(* {1 Objects} *)
(*****************************************************************************)

val new_object : unit -> obj
val new_array : value list -> obj
val host_function : string -> (this:value -> value list -> value) -> value
val host_object : host -> value


(* returns a property's cell in a list of properties, by its key *)
val property : string -> (string * value ref) list -> value ref option

(* an own property, if the object has it *)
val get_own : obj -> string -> value option

(* sets a property, or adds it at the end of the keys *)
val set_own : obj -> string -> value -> unit

(* returns the keys, in the order they were added *)
val keys : obj -> string list

(* returns all of its own keys, including those that do not show
 * (getOwnPropertyNames) *)
val all_keys : obj -> string list

(* [hide] makes a key not show, [show] makes it show again, and [shows]
 * says whether it does *)
val hide : obj -> string -> unit
val show : obj -> string -> unit
val shows : obj -> string -> bool

val array_items : obj -> value list

(* makes an error object, {name, message}: [error "TypeError" "x is not
 * a function"] *)
val error : string -> string -> value

(* raises one: [throw "RangeError" "..."] *)
val throw : string -> string -> 'a

(* says whether a text has another in it *)
val contains : string -> string -> bool

(* ix: the debugging switches, which a host sets (they were the
 * environment's JS_THROWS, JS_THROWS_NOT, JS_STACK). They say how many
 * thrown values to report, except those with the given words, and the
 * words of an error whose calls are reported as it leaves them ("" or
 * "1" for a full stack). What is reported goes to [say] (nowhere unless
 * a host gives a way). The wall clock belongs to the host too (it is 0
 * unless given, and a run is then not stopped by the clock). *)
val say : (string -> unit) ref
val wall_clock : (unit -> float) ref
val stack_words : string option ref
val throws_left : int ref
val throws_not : string option ref

(* reports a thrown value, the first [throws_left] times *)
val thrown : (unit -> string) -> unit

(* JS_STACK's count of calls still to report (Js_eval reports them) *)
val unwinding : int ref

(*****************************************************************************)
(* {1 Conversions} *)
(* [flatten] writes out a rope's text, once. [flat] gives a value that
 * is a rope as the String it is. [join] joins two strings (or ropes):
 * the result is a String when it is short, and a rope otherwise, so
 * that a text grown by adding to it is not copied at each addition. *)
val flatten : rope -> string
val flat : value -> value
val join : value -> value -> value

(*****************************************************************************)

val typeof : value -> string
val truthy : value -> bool
val to_primitive : value -> value

(* the same, with the hint given: "string" or "number" (ix: it was
 * to_primitive's ?hint) *)
val to_primitive_as : string -> value -> value

(* called on a property read on a host's object when neither the
   object nor its prototypes have it, with its class and the name. It
   is None by default, and then nothing is called. *)
val missing : (string -> string -> unit) option ref

(* an object's own way to be a primitive (its Symbol.toPrimitive, its
 * valueOf, its toString, written in JavaScript), asked of the engine
 * that is running. Js_eval sets it, and [to_primitive] asks it for a
 * plain object. [hint] is "number", "string" or "default". *)
val own_primitive : (value -> string -> value option) ref
val to_string : value -> string
val to_number : value -> float

(* ===: the same kind and value, or for objects the same object; NaN
 * is not NaN *)
val strict_equal : value -> value -> bool

(* how the console shows a value: a string as it is at the top, and
 * quoted inside; [1, "a"]; {a: 1, b: [2]}; function f *)
val display : value -> string

(* JSON.stringify's text: objects' keys in order, undefined and
 * functions left out of objects (and null in arrays), and an error for
 * a cycle *)
val to_json : value -> string option
