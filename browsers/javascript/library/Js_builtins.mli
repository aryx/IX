(* Js_builtins: what a script finds already there -- console, Math,
   String, Number, parseInt, JSON, Object.keys -- and the methods of
   strings and arrays.

   (mini-chrome's notes_javascript.md, section 8.) They are host
   functions (Js_value's Host_function), OCaml
   functions the engine calls like the script's own. A method call on a
   string or an array ("abc".toUpperCase(), xs.map(f)) finds its method
   in its kind's **prototype** object, [protos] (String.prototype,
   Array.prototype), at the end of the chain Js_eval walks: a script can
   read them, call them on other things, and add its own (TinyChrome's
   C8, a stage of mini-chrome's first plan; class, the exercise left
   then, is Js_eval's since).

     "abc".toUpperCase()      "abc" is no object: its methods are looked
                              for in protos.strings, where toUpperCase is
                              a Host_function; called with this = "abc"
     String.prototype.shout = function () { return this + "!" }
     "abc".shout()            the same object, a property more: "abc!"

   cs-history:
   What is there tells who was copied, and when. Math and Date are
   Java's of 1995, taken in the ten days: Date with java.util.Date's
   mistakes, months counted from 0 and getYear's years since 1900,
   which Java deprecated in 1997 and JavaScript cannot. The strings'
   methods are Perl's and Java's. The arrays' forEach, map and filter
   are of functional languages and came late: Firefox 1.5
   (2005) as "array extras", the standard in ES5 (2009); before them
   every library shipped its own each (Underscore is that library).
   And how thin the standard library stayed was shown in March 2016,
   when one author withdrew his eleven-line left-pad from the npm
   registry and thousands of builds failed: padStart was added to the
   language the next year.

     console      log (its arguments shown, joined by spaces), error, warn
     Math         floor ceil round trunc abs sign sqrt pow min max random PI
     String, Number, Boolean, parseInt, parseFloat, isNaN
     JSON         stringify
     Object.keys, create, getPrototypeOf, assign; Array.isArray, from
     RegExp, Date (Date.now, its getters), Error and its kinds
     encodeURIComponent, decodeURIComponent, encodeURI, String.fromCharCode
     strings      toUpperCase toLowerCase slice substring charAt indexOf includes
                  startsWith endsWith split trim repeat padStart concat
                  lastIndexOf charCodeAt substr match replace search (with
                  a regular expression or a string), split by one
     arrays       push pop shift unshift join indexOf includes slice concat
                  reverse sort forEach map filter reduce find findIndex some every
                  splice lastIndexOf

   Math.random is **seeded** (Lehmer's generator, the Playground's:
   Lehmer.mli), so that a page of TinyFirefox (mini-netscape, here)
   draws the same numbers each run and a golden frame stays golden:
   mini-node's first Math.random() is the same number at every run.

   A function given to map, forEach, sort ... is called back through
   [call], the interpreter's (Js_eval), passed in rather than named, so
   that this module needs nothing of the interpreter.

   Where it stands: three layers make what a script finds. This one,
   in OCaml, for what ES5 had and what needs the engine's insides;
   Js_globals, in OCaml, for what libraries test for (Symbol, Map,
   Proxy); Js_prelude, in JavaScript, for what ES2016 and after added
   and can be written over the first two. Js_eval.create_with
   installs the three in that order. What is the browser's and not
   the language's (document, window, setTimeout, fetch) is a host's:
   Browser_script's, and mini-node has none of it.

   wib:
   sort with no function compares its items as strings: [10, 9, 1]
   sorted is [1, 10, 9], here as everywhere. An array may hold
   anything, and the one order that anything has is its text's: the
   rule is simple to state and to implement, and wrong for the most
   common case. Pages count on it, so it stays, and every programmer
   learns to write sort((a, b) => a - b).

   Reference: ECMA-262 5.1, section 15 (the standard built-in
   objects: 15.4 Array, 15.5 String, 15.8 Math, 15.9 Date); Brendan
   Eich and Allen Wirfs-Brock, "JavaScript: The First 20 Years" (HOPL
   IV, 2020), for where each came from. *)
(* ix: the author's mini-chrome's languages/javascript/library/Js_builtins.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* the prototypes: the objects a property not an object's own is looked
 * for in next -- a string's, an array's, a plain object's
 * (Object.prototype: hasOwnProperty, toString), a function's
 * (Function.prototype: call, apply, bind), a regular expression's
 * (exec, test), a number's (toFixed) -- each also its constructor's
 * prototype property (String.prototype, Array.prototype...), where a
 * script finds them, calls them on other things (hn.js's
 * Array.prototype.indexOf.call(a, x)), or adds its own *)
type protos = { strings : Js_value.obj; arrays : Js_value.obj; objects : Js_value.obj; functions : Js_value.obj; regexps : Js_value.obj; numbers : Js_value.obj }

(* what hasOwnProperty asks a host object, before the property's name:
 * a host keeps what a script put on it itself (an element's
 * properties), and answers true for those *)
val own_query : string

(* an iterator over these values: next(), and itself as its
 * [Symbol.iterator]() *)
val iterator : Js_value.value list -> Js_value.value

(* a RegExp object of [re], its prototype [proto]: a literal's *)
val regexp_value : Js_value.obj -> Js_regexp.t -> Js_value.value

(* [install ~call ~get ~put ~items ~compile ~log ~seed ~now define]:
 * every global [define]d, console writing to [log], Math.random from
 * [seed], Date's clock [now] (milliseconds since 1970; 0 unless
 * given); the prototypes. What the interpreter does for them: [call] a
 * function, [get] and [put] a property (an array's method on what is
 * only like an array), [items] of what can be gone through
 * (Array.from), [compile] a function from its parameters' and its
 * body's text (new Function) *)
val install :
  call:(Js_value.value -> this:Js_value.value -> Js_value.value list -> Js_value.value) ->
  get:(Js_value.value -> string -> Js_value.value) ->
  put:(Js_value.value -> string -> Js_value.value -> unit) ->
  items:(Js_value.value -> Js_value.value list) ->
  compile:(async:bool -> string -> string -> Js_value.value) ->
  log:(string -> unit) ->
  seed:int ->
  now:(unit -> float) ->
  (string -> Js_value.value -> unit) ->
  protos
