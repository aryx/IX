(* Js_globals is the rest of the standard library: what libraries look
   for before they do anything, such as the helpers of Object, Array
   and Number, Symbol, Map and Set.

   Js_builtins has what a page's own script uses (strings, arrays,
   Math, JSON, Date). A library (jQuery, React, Underscore) starts by
   taking stock of the engine: "var _isFinite = isFinite", "typeof
   Symbol === 'function' && Symbol.for", "Object.defineProperty(exports,
   '__esModule', { value: true })". It stops at the first one that is
   not there. They are here:

   evolution:
   Taking stock of the engine is a habit learned the hard way. Pages
   first asked the browser its name and believed it (Script_window.mli
   tells where that led). Then they tested for the thing itself ("if
   (document.getElementById)", in the 2000s); Modernizr (2009) is a
   library of nothing but such tests. Then, where the test failed,
   they supplied the thing: a "polyfill" (Remy Sharp's word, 2010,
   after a brand of filler for cracks in a wall), JavaScript that
   defines Object.keys or Promise on an engine that lacks it. So a
   library written for today's language runs on yesterday's engine if
   enough of the old language is there to build the new one from,
   which is what this module is for, from the other side.

     isFinite, globalThis
     Number.isFinite .isInteger .isNaN .MAX_SAFE_INTEGER .EPSILON ...
     Object.defineProperty .defineProperties .getOwnPropertyNames
           .getOwnPropertyDescriptor .entries .values .fromEntries
           .freeze .isFrozen .seal .setPrototypeOf ...
     Array.of
     Symbol(), Symbol.for, Symbol.iterator
     Map, Set, WeakMap, WeakSet
     Uint8Array, Int32Array, Float64Array ...
     Reflect

   Some of them are less than the real thing, and say so:

   **A typed array is an array**: new Uint8Array(4) is four zeros, and
   new Uint8Array([1, 2]) is a copy. There is no ArrayBuffer under it,
   and a number is not wrapped to its type's range. That is right for
   the tables of small numbers that a library keeps in one (Vue's
   tokenizer), but not for bytes.

   **Object.defineProperty** sets a value, or a getter and a setter
   (Js_value's Accessor). Of its flags, enumerable is kept: a key made
   without it is put in the object's hidden list, which for-in,
   Object.keys and JSON pass over. writable and configurable are not
   kept, so every property can be written and deleted. So **freeze**
   freezes nothing, and isFrozen says false.

   **A symbol** is a value of its own (Js_value.Symbol; typeof gives
   "symbol"), and what it holds is the key it makes when it is used
   as a property's key: a string that no script writes, such as
   "@@iterator" or "@@7:description". So an object's properties stay
   keyed by strings, and such a key is left out of for-in and
   Object.keys because of its "@@". Object.getOwnPropertySymbols gives
   none.

   **Map and Set** keep their entries in a list, in the order they
   came, and get and has look through it (SameValueZero: === except
   that NaN is NaN). That is right for the tens of entries a page has.
   A hash table is the real one, and with Mini_opti on it is the one
   used here ([store]'s two ways): a library that kept what
   it knows of every object in maps of thousands of entries made the
   list take the page's whole time. keys(), values() and entries()
   give iterators over what was there when they were asked
   (Js_builtins.iterator). WeakMap and WeakSet are Map and Set:
   nothing is collected.

   **There is no proxy** (ES2015's new Proxy(target, handler), an
   object seen through a handler's traps). A proxy is how a library
   knows what a page read and what it changed, to draw again only what
   depends on it (Vue's reactivity, Alpine's data), and mini-chrome
   has it. Here a page whose framework needs one shows as it is, and
   does not react (ocaml.org's menus: plan_browser.md, C). Reflect has
   each operation on an object as a function.

   Where it stands: Js_eval.create_with installs this module after
   Js_builtins, and before Js_prelude's text is run (that text adds, in
   JavaScript, an ArrayBuffer and a DataView of its own, WeakRef, and
   the rest of what came after 2015). In a page, the libraries this is
   for are the ones mini-netscape meets on the live web. mini-node can
   show each global with a line: typeof Symbol.iterator is "symbol".

   Reference: ECMA-262, sections 28.1 (Reflect), 20.1 (Object), 20.4
   (Symbol), 21.1 (Number), 24.1 and 24.2 (Map, Set). *)
(* ix: copied from languages/javascript/library/Js_globals.mli in the
 * author's mini-chrome, at its commit 8af888e (docs/plans/plan_browser.md) *)

(* a symbol's string: "@@" and what it is *)
val is_symbol : string -> bool

(* [install ~call ~lookup ~get ~put ~has ~items define] [define]s the
 * globals above, and adds their statics to the constructors that
 * [lookup] finds (Object, Array, Number: Js_builtins'). [call] calls a
 * function (a Map's forEach). [get], [put] and [has] are the
 * interpreter's (for Reflect). [items] gives the items of what can be
 * gone through (new Set(iterable)). *)
val install :
  call:(Js_value.value -> this:Js_value.value -> Js_value.value list -> Js_value.value) ->
  lookup:(string -> Js_value.value option) ->
  get:(Js_value.value -> string -> Js_value.value) ->
  put:(Js_value.value -> string -> Js_value.value -> unit) ->
  has:(Js_value.value -> string -> bool) ->
  items:(Js_value.value -> Js_value.value list) ->
  (string -> Js_value.value -> unit) ->
  unit
