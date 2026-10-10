(* Js_props: an object's properties -- read, written, asked about,
   listed -- and the chain of prototypes behind them.

   (mini-chrome's notes_javascript.md, section 6.) A JavaScript object
   is a list of properties and a link to another object, its
   **prototype**; what it does not have itself it has from that one,
   and so on up:

   cs-history:
   Objects without classes were Self's idea (David Ungar and Randall
   Smith, Xerox PARC, 1986): a new object is a copy of another, or
   points to it for what it lacks; there is nothing but objects.
   Brendan Eich put it under JavaScript's Java-like surface in 1995,
   which is why "new Point(1, 2)" looks like a class being
   instantiated and is a function being called with a fresh object
   whose prototype is Point.prototype. The link itself could not be
   named at first (Netscape's __proto__ was its own); ES5 (2009) gave
   Object.create and getPrototypeOf, Douglas Crockford having argued
   for years that the prototypes were the good part and "new" the
   disguise. The class of ES2015 is a notation for exactly this chain,
   not another model (Js_eval.make_class).

     var p = new Point(1, 2)        p            {x: 1, y: 2}
     p.sum()                         -> Point.prototype   {sum: function, constructor: Point}
     p.hasOwnProperty("x")              -> Object.prototype   {hasOwnProperty: ...}

   [get] follows that chain. A value that is no object has one all the
   same: a string's methods are String.prototype's, an array's
   Array.prototype's -- the built-ins' prototypes ([Js_builtins.protos]),
   given to each function here, so that this module knows nothing of
   the interpreter. A function's own "prototype" (what its new objects
   will link to) is made the first time it is asked for.

   An array's indices and length, a string's characters and length, and
   a host object's properties (the DOM's: Script_host) are not in the
   list: they are answered here from what the value is.

   Writing ([set]) is always to the object itself, never up the chain.

   [enumerable_keys] is for (k in o)'s list: the object's own keys in
   the order they were set, then those of the prototypes it was given
   -- not the built-in ones', whose methods do not show in a for-in,
   nor a prototype's "constructor". (There is no flag a property for
   "enumerable": that rule stands for it, with a list an object has
   of its own keys that do not show, Js_value.obj's hidden: a class's
   methods, what Object.defineProperty made without saying so.)

   Where it stands: Js_eval calls [get] and [set] for every o.k and
   o[k] (after a Proxy's traps and a host object's own way), Js_compile
   the same, Js_builtins for what its methods read of their
   arguments. The walk up the chain is mini-smalltalk's too, with one
   difference that is the whole of classes against prototypes: there
   an object has only its fields, and a message's method is looked
   for in its class, then the superclass (St_interp.mli, St_class's
   lookup); here an object may have the method itself, and what
   stands above it is just another object.

     Smalltalk    p --class--> Point --superclass--> Object
                  fields only  methods               methods
     JavaScript   p --proto--> Point.prototype --proto--> Object.prototype
                  anything     anything                   anything

   Reference: David Ungar and Randall Smith, "Self: The Power of
   Simplicity" (OOPSLA 1987); Douglas Crockford, "JavaScript: The Good
   Parts" (2008), chapter 3; ECMA-262 5.1, sections 8.12 (an object's internal
   methods: [[Get]], [[Put]], [[HasProperty]]), 12.6.4 (for-in), 15.3.5.3
   (instanceof). *)
(* ix: the author's mini-chrome's languages/javascript/values/Js_props.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* the array index a key names, if it is one: "3", not "03" nor "-1" *)
val index_of_key : string -> int option

(* a value as a property's key: 3 is "3", 1.5 is "1.5", else its string *)
val key_of : Js_value.value -> string

(* an object's prototype: its own, else its kind's (an array's is
 * Array.prototype), Object.prototype last, and nothing after it *)
val proto_of : Js_builtins.protos -> Js_value.obj -> Js_value.obj option

(* [get protos v k]: v.k, up the prototypes; TypeError if [v] is
 * undefined or null *)
val get : Js_builtins.protos -> Js_value.value -> string -> Js_value.value

(* k in o: its own or its prototypes' *)
val has : Js_builtins.protos -> Js_value.obj -> string -> bool

(* v instanceof F: F.prototype is in v's chain *)
val instance_of : Js_builtins.protos -> Js_value.value -> Js_value.value -> bool

(* v.k = x: on the object itself (an array grown, its length set; a
 * host object asked); lost on a primitive; TypeError on undefined or
 * null *)
val set : Js_value.value -> string -> Js_value.value -> unit

(* the keys a for (k in v) goes through *)
val enumerable_keys : Js_value.value -> string list

(* the name of the property that marks a prototype as the browser's own
 * (Node.prototype, HTMLElement.prototype...): on a host object, what a
 * page's class has of a name comes before what the browser answers,
 * and the page's prototypes are those above the first marked one *)
val dom_mark : string

