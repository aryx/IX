(* Js_globals: the rest of the standard library, what libraries look
   for before they do anything -- the helpers of Object, Array and
   Number, Symbol, Map and Set.

   Js_builtins has what a page's own script uses (strings, arrays,
   Math, JSON, Date). A library (jQuery, React, Underscore) starts by
   taking stock of the engine: "var _isFinite = isFinite", "typeof
   Symbol === 'function' && Symbol.for", "Object.defineProperty(exports,
   '__esModule', { value: true })" -- and stops at the first that is
   not there. They are here:

   evolution:
   Taking stock of the engine is a habit learned the hard way. Pages
   first asked the browser its name and believed it (Script_window.mli
   tells where that led). Then they tested for the thing itself --
   "if (document.getElementById)", in the 2000s; Modernizr (2009) is a
   library of nothing but such tests. Then, where the test failed,
   they supplied the thing: a "polyfill" (Remy Sharp's word, 2010,
   after a brand of filler for cracks in a wall), JavaScript that
   defines Object.keys or Promise on an engine that lacks it. So a
   library written for today's language runs on yesterday's engine if
   enough of the old language is there to build the new one from --
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
     Proxy, Reflect

   Some of them are less than the real thing, and say so:

   **A typed array is an array**: new Uint8Array(4) is four zeros, new
   Uint8Array([1, 2]) a copy. There is no ArrayBuffer under it, and a
   number is not wrapped to its type's range: right for the tables of
   small numbers a library keeps in one (Vue's tokenizer), not for
   bytes.

   **Object.defineProperty** sets a value, or a getter and a setter
   (Js_value's Accessor). Its flags -- writable, enumerable,
   configurable -- are not kept: every property can be written and
   deleted. So **freeze** freezes nothing, and isFrozen says false.

   **A symbol** is a value of its own (Js_value.Symbol; typeof gives
   "symbol"), and what it holds is the key it makes as a property's:
   a string no script writes, "@@iterator" or "@@7:description". So an
   object's properties stay keyed by strings, and such a key is left
   out of for-in and Object.keys by its "@@". Object.getOwnPropertySymbols
   gives none.

   **Map and Set** keep their entries in a list, in the order they
   came: get and has look through it (SameValueZero: === but NaN is
   NaN). Right for the tens of entries a page has; a hash table is the
   real one. keys(), values() and entries() give iterators over what
   was there when they were asked (Js_builtins.iterator). WeakMap and WeakSet
   are Map and Set: nothing is collected.

   **A proxy** (ES2015) is an object seen through a handler's traps:

     const seen = []
     const p = new Proxy({ a: 1 }, {
       get(target, key) { seen.push(key); return Reflect.get(target, key) },
       set(target, key, value) { target[key] = value * 2; return true } })
     p.a; p.b = 2; p.b          // seen: a, b; p.b is 4

   which is how a library knows what a page read and what it changed,
   to draw again only what depends on it (Vue's reactivity, Alpine's
   data). The traps here are get, set, has (k in p, and a with's
   names), deleteProperty, apply (a proxy of a function) and ownKeys
   (for-in). What does not go through a trap sees the target as it
   is: JSON.stringify, Object.keys, the console, a for-of. Reflect has
   each operation as a function, for a trap that wants the usual.

   Reference: ECMA-262, sections 28.1 (Reflect), 28.2 (Proxy), 20.1 (Object), 20.4 (Symbol), 21.1
   (Number), 24.1 and 24.2 (Map, Set). *)
(* ix: the author's mini-chrome's languages/javascript/library/Js_globals.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* a symbol's string: "@@" and what it is *)
val is_symbol : string -> bool

(* [install ~call ~lookup ~get ~put ~has define]: the globals above
 * [define]d, their statics added to the constructors [lookup] finds
 * (Object, Array, Number: Js_builtins'); [call] a function called (a
 * Map's forEach); [get], [put] and [has], the interpreter's, through a
 * proxy's traps (Reflect's); [items], of what can be gone through
 * (new Set(iterable)) *)
val install :
  call:(Js_value.value -> this:Js_value.value -> Js_value.value list -> Js_value.value) ->
  lookup:(string -> Js_value.value option) ->
  get:(Js_value.value -> string -> Js_value.value) ->
  put:(Js_value.value -> string -> Js_value.value -> unit) ->
  has:(Js_value.value -> string -> bool) ->
  items:(Js_value.value -> Js_value.value list) ->
  (string -> Js_value.value -> unit) ->
  unit
