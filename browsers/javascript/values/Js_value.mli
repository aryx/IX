(* Js_value: JavaScript's values, and how it converts one into another.

   (mini-chrome's notes_javascript.md, sections 4 and 7.) Seven kinds,
   and symbol (a value of its own: Js_globals.mli), less bigint (10n
   is the number 10: Js_lexer's):

   cs-history:
   The kinds are those of 1995, and their oddities with them. A number
   is a float, the only kind of number until BigInt (2020): the first
   engine had integers inside but the language never showed them.
   typeof null is "object": in that engine a value was a tagged word,
   the tag 0 meant an object, and null was the zero pointer -- a bug of
   the first week; its repair was proposed, and refused, because pages
   test for it. And the conversions (+ with a string concatenates, ==
   converts before comparing) were asked of Brendan Eich by the first
   users, who wanted "1" == 1 to be true for the text of a form's
   field; by his own account he regrets granting it. === (JavaScript
   1.3, 1998; ES3, 1999) is the comparison without them.

     undefined  null  boolean  number (a float: 1 is 1.0)  string  object  function

   An **object** is a table from names to values, mutable, its keys kept
   in the order they were added. An **array** is an object whose items
   are a growable OCaml array, [length] and indexing done on it
   directly -- what engines do too, behind the same appearance. A
   **function** is an object holding a closure (its parameters, its
   body, and the scope it was created in: [scope]) or an OCaml function
   (a host function: console.log, and the browser's). Objects are
   compared, passed and stored by reference: [{} === {}] is false.

   A **host object** is the browser's: document, an element, whose
   properties are OCaml functions reading and changing the page (Js_eval
   calls [get] and [set] where it would look in the table).

   A string is OCaml's, UTF-8, as the rest of the browser's text. Its
   [length] and indexes were once its bytes' ("é".length was 2 where
   JavaScript, counting UTF-16 units, says 1), right while the pages
   were ASCII where it mattered; they are now counted as the language
   says, over the same bytes: Js_utf16, and its interface tells what
   page it took.

   How the types hold one another ([value], [obj], [kind] below):

     value   Undefined | Null | Bool | Number | String | Rope | Symbol
               | Object of obj
     obj     props   its own properties, a list, the newest first
             proto   another obj, or none: where a property it has
                     not is looked for next (Js_props)
             kind    Plain | Array (its items, apart from props)
                     | Closure (a func of Js_ast, and the scope it was
                       written in)
                     | Host_function (OCaml's) | Host_object (a page's
                       element) | Regexp | Proxy | Accessor

   So a function is an object with a kind, which is why f.x = 1 works
   and typeof must look at the kind to say "function"; and a scope
   (Js_scope's, whose type is here because a closure holds one) is
   reached from any function value: what a closure keeps alive is
   OCaml's collector's to find, and the engine has none of its own.

   A long string made by [+] is a **rope**: the two pieces, kept as
   they are, and written end to end only when the text is first read.
   A script that builds a text by adding to it -- s += c, ten thousand
   times -- would otherwise copy all it has at each addition, the
   square of the text's length in all.

   cs-history:
   Ropes are Boehm, Atkinson and Plass's, of Xerox PARC's Cedar: a
   string as a tree of pieces, so that joining two is one small node
   whatever their lengths ("Ropes: an Alternative to Strings",
   Software: Practice and Experience, 1995).

   modern:
   Every JavaScript engine has them, for this very loop: V8's
   ConsString, SpiderMonkey's JSRope, flattened in place the first
   time the characters are asked for. Here a rope is kept out of
   OCaml's sight rather than taught to all of it: it lives in a
   script's variables, and whatever is stored in an object or given
   to a function of ours is made a String first ([flat]).

   **Conversions**, JavaScript's, which convert rather than refuse:
   [to_string], [to_number], [truthy] (false, 0, NaN, "", null and
   undefined are false; everything else, "0" and [] included, true), and
   [to_primitive] (an array is its items joined with commas, an object
   "[object Object]"). Section 7's table is Js_eval's [+], built on
   them (Js_operators).

   others:
   One type with a constructor a kind is how an interpreter written
   in ML has its values, and OCaml's own tag does the work: a match
   is typeof. An engine in C packs the same in a machine word. The
   first one's tagged word is told above; today's use the floats
   themselves: of the 2^64 patterns of a double, about 2^53 are NaNs
   and arithmetic makes one of them, room for a pointer and a tag in
   the others
   ("NaN boxing", SpiderMonkey's and JavaScriptCore's), or keep small
   integers apart from pointers by a low bit (V8's Smi), as OCaml
   does for its int. Here a Number is a float in a box, allocated at
   each addition: Js_compile.mli's last lines say what that costs.

   Reference: ECMA-262, section 6.1 (the language's types) and 7.1
   (the conversions: ToPrimitive, ToNumber, ToString, ToBoolean);
   Hans Boehm, Russ Atkinson and Michael Plass, "Ropes: an Alternative
   to Strings" (Software: Practice and Experience, 1995). *)
(* ix: the author's mini-chrome's languages/javascript/values/Js_value.mli (its 8af888e) (docs/plans/plan_browser.md) *)

type value =
  | Undefined
  | Null
  | Bool of bool
  | Number of float
  | String of string
  (* a long string not yet written out: two pieces joined by +, put end
   * to end when it is first read ([flatten]). It lives where a script
   * keeps what it is computing -- a variable, an argument of a
   * function of the script -- and is made a String wherever a value is
   * stored or given to OCaml ([flat]): a property, an array, a host
   * function. So only the evaluator meets one *)
  | Rope of rope
  (* a symbol (ES2015): a unique value, usable as a property's
   * key. What it holds is that key, "@@7:description" or a well-known
   * one's, "@@iterator": a string no script writes *)
  | Symbol of string
  | Object of obj

and rope = { mutable pieces : pieces; size : int; (* its bytes *) units : int (* its length, as a script counts it: Js_utf16 *) }
and pieces = Flat of string | Cat of rope * rope

and obj = {
  id : int; (* for printing cycles and for tests; identity is (==) *)
  mutable props : (string * value ref) list; (* the newest first: keys in order, reversed *)
  kind : kind;
  mutable proto : obj option; (* its prototype: where a property it does not have is looked for next *)
  mutable lookup : lookup option; (* its properties by their key, when they are many (Js_value's find) *)
  (* its own keys that do not show (not enumerable): a class's methods,
   * what Object.defineProperty made without saying enumerable. They
   * are read and written as the others; for-in, Object.keys, a spread
   * and JSON pass them *)
  mutable hidden : string list;
}

(* an object's properties in a table, good while its list is the one
 * the table was made from (==): what writes the list itself -- a
 * delete -- makes it stale with no word said *)
and lookup = { table : (string, value ref) Hashtbl.t; mutable of_props : (string * value ref) list }

and kind =
  | Plain
  | Array of items
  | Closure of closure
  | Host_function of string * (this:value -> value list -> value) (* its name, and it *)
  | Host_object of host
  | Regexp of Js_regexp.t (* a regular expression (its lastIndex a property) *)
  (* not an object a script sees: what a property is when it is a
   * getter and a setter ({ get k() { } }, Object.defineProperty): the
   * two functions, undefined for the one it has not. Reading the
   * property calls the first, assigning to it the second (Js_eval) *)
  | Accessor of value * value
  (* new Proxy(target, handler): the target, seen through the
   * handler's traps -- reading a property calls handler.get, setting
   * one handler.set, "k in p" handler.has (Js_eval; a trap the handler
   * has not: the target's own way). What it is otherwise (an array, a
   * function, its keys) is what its target is *)
  | Proxy of obj * obj

(* an object whose properties are the host's functions: reading one
 * calls [get], writing one [set] (the spec's getters and setters) --
 * a page's element, whose textContent is its tree's text, not a value
 * stored; [show], how the console shows it *)
and host = { class_name : string; get : string -> value; set : string -> value -> unit; show : unit -> string }

and items = { mutable elements : value array; mutable length : int; mutable holes : int (* its first items never given (new Array(3)): skipped by map and forEach while still undefined *) }

and closure = { func : Js_ast.func; scope : scope; this : value option (* an arrow's, captured *) }

(* a frame of names, and the frame around it *)
(* [subject] is the object of a with (obj) { }: a name that is
 * a property of it is that property; [in_with] says whether this
 * frame or one around it has one (else no frame is asked); [strict]:
 * the code here is in strict mode ("use strict", a module, a class) *)
and scope = { vars : vars; parent : scope option; subject : value option; in_with : bool; strict : bool }

(* a scope's names: a table of them, the simple way; or, opti, an array
 * of bindings in the order they were declared, their names beside
 * (the first [used] of each), and when they are many an index of the
 * first [fixed] of them, never written once made (Js_scope) *)
and vars = Table of (string, binding) Hashtbl.t | Slots of slots
and slots = { mutable names : string array; mutable cells : binding array; mutable used : int; mutable index : (string, int) Hashtbl.t option; mutable fixed : int }
and binding = { mutable value : value; constant : bool }

(* a JavaScript exception, thrown by [throw] or by the engine: any value,
 * usually an error object *)
exception Throw of value

(* opti: a function's body compiled: given the call's frame and its
 * this, what the call returns (Js_compile makes it, Js_eval calls it) *)
exception Compiled of (scope -> value -> value)

(*****************************************************************************)
(* {1 Objects} *)
(*****************************************************************************)

val new_object : unit -> obj
val new_array : value list -> obj
val host_function : string -> (this:value -> value list -> value) -> value
val host_object : host -> value

(* a proxy's target, through proxies of proxies; any other object: itself *)
val target : obj -> obj

(* an own property, if the object has it *)
(* a property's cell in a list of properties, by its key *)
val property : string -> (string * value ref) list -> value ref option

val get_own : obj -> string -> value option

(* set, or add at the end of the keys *)
val set_own : obj -> string -> value -> unit

(* the keys, in the order they were added *)
val keys : obj -> string list

(* all of its own keys, those that do not show too (getOwnPropertyNames) *)
val all_keys : obj -> string list

(* a key made not to show, to show again; whether it does *)
val hide : obj -> string -> unit
val show : obj -> string -> unit
val shows : obj -> string -> bool

val array_items : obj -> value list

(* an error object, {name, message}: [error "TypeError" "x is not a
 * function"] *)
val error : string -> string -> value

(* raise one: [throw "RangeError" "..."] *)
val throw : string -> string -> 'a

(* whether a text has another in it *)
val contains : string -> string -> bool

(* ix: the debugging switches, a host's to set (they were the
 * environment's JS_THROWS, JS_THROWS_NOT, JS_STACK): how many values
 * thrown to say, but those with these words; the words of an error
 * whose calls are said as it leaves them ("" or "1": a full stack's).
 * What is said goes to [say] (nothing unless a host gives a way); the
 * wall clock is the host's too (0 unless given: a run is then not
 * stopped by the clock) *)
val say : (string -> unit) ref
val wall_clock : (unit -> float) ref
val stack_words : string option ref
val throws_left : int ref
val throws_not : string option ref

(* a value thrown is said, the first [throws_left] times *)
val thrown : (unit -> string) -> unit

(* JS_STACK's count of calls still to say (Js_eval says them) *)
val unwinding : int ref

(*****************************************************************************)
(* {1 Conversions} *)
(* a rope's text, written out once; a value that is a rope as the
 * String it is; and two strings (or ropes) joined: a String when
 * short, else a rope -- a text grown by adding to it is then not
 * copied at each addition *)
val flatten : rope -> string
val flat : value -> value
val join : value -> value -> value

(*****************************************************************************)

val typeof : value -> string
val truthy : value -> bool
val to_primitive : value -> value

(* the same, the hint said: "string", "number" (ix: it was to_primitive's ?hint) *)
val to_primitive_as : string -> value -> value

(* an object's own way to be a primitive (its Symbol.toPrimitive, its
 * valueOf, its toString, written in JavaScript), asked of the engine
 * that is running: Js_eval sets it, [to_primitive] asks it for a plain
 * object. [hint]: "number", "string" or "default" *)
(* told of a property read on a host's object that neither it nor its
   prototypes have: its class, the name. None (the default): not told *)
val missing : (string -> string -> unit) option ref

val own_primitive : (value -> string -> value option) ref
val to_string : value -> string
val to_number : value -> float

(* ===: the same kind and value; objects the same object; NaN is not
 * NaN *)
val strict_equal : value -> value -> bool

(* how the console shows a value: a string as it is at the top, quoted
 * inside; [1, "a"]; {a: 1, b: [2]}; function f *)
val display : value -> string

(* JSON.stringify's text: objects' keys in order, undefined and
 * functions left out of objects (null in arrays), a cycle an error *)
val to_json : value -> string option
