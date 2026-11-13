(* Js_props handles an object's properties (reading them, writing them,
   asking about them, listing them) and the chain of prototypes behind
   them.

   (See mini-chrome's notes_javascript.md, section 6.) A JavaScript
   object is a list of properties and a link to another object, its
   **prototype**. What it does not have itself, it has from that one,
   and so on up:

   cs-history:
   Objects without classes were Self's idea (David Ungar and Randall
   Smith, Xerox PARC, 1986): a new object is a copy of another, or it
   points to another for what it lacks, and there is nothing but
   objects. Brendan Eich put this under JavaScript's Java-like surface
   in 1995. That is why "new Point(1, 2)" looks like a class being
   instantiated, while it is a function being called with a fresh
   object whose prototype is Point.prototype. The link itself could not
   be named at first (Netscape's __proto__ was its own extension). ES5
   (2009) gave Object.create and getPrototypeOf, after Douglas
   Crockford had argued for years that the prototypes were the good
   part and "new" the disguise. The class of ES2015 is a notation for
   exactly this chain, not another model (Js_eval.make_class).

     var p = new Point(1, 2)        p            {x: 1, y: 2}
     p.sum()                         -> Point.prototype   {sum: function, constructor: Point}
     p.hasOwnProperty("x")              -> Object.prototype   {hasOwnProperty: ...}

   [get] follows that chain. A value that is not an object has a chain
   all the same: a string's methods are String.prototype's, and an
   array's are Array.prototype's. These are the built-ins' prototypes
   ([Js_builtins.protos]), which are given to each function here, so
   that this module knows nothing of the interpreter. A function's own
   "prototype" (what its new objects will link to) is made the first
   time it is asked for.

   An array's indices and length, a string's characters and length, and
   a host object's properties (the DOM's: Script_host) are not in the
   list. They are answered here from what the value is.

   Writing ([set]) is always to the object itself, never up the chain.

   [enumerable_keys] gives the list for (k in o): the object's own keys
   in the order they were set, then those of the prototypes it was
   given. It leaves out the built-in prototypes' keys, whose methods do
   not show in a for-in, and a prototype's "constructor". (There is no
   "enumerable" flag on a property. That rule stands for it, together
   with an object's own list of its keys that do not show,
   Js_value.obj's hidden: a class's methods, and what
   Object.defineProperty made without saying enumerable.)

   Where it stands: Js_eval calls [get] and [set] for every o.k and
   o[k] (after a host object's own way), Js_compile does the same, and
   Js_builtins calls them for what its methods read of their
   arguments. mini-smalltalk walks up a chain too, with one
   difference that is the whole of classes against prototypes. There,
   an object has only its fields, and a message's method is looked for
   in its class, then in the superclass (St_interp.mli, St_class's
   lookup). Here, an object may have the method itself, and what stands
   above it is just another object.

     Smalltalk    p --class--> Point --superclass--> Object
                  fields only  methods               methods
     JavaScript   p --proto--> Point.prototype --proto--> Object.prototype
                  anything     anything                   anything

   Reference: David Ungar and Randall Smith, "Self: The Power of
   Simplicity" (OOPSLA 1987); Douglas Crockford, "JavaScript: The Good
   Parts" (2008), chapter 3; ECMA-262 5.1, sections 8.12 (an object's
   internal methods: [[Get]], [[Put]], [[HasProperty]]), 12.6.4
   (for-in), 15.3.5.3 (instanceof). *)
(* ix: copied from languages/javascript/values/Js_props.mli in the
 * author's mini-chrome, at its commit 8af888e (docs/plans/plan_browser.md) *)

(* the array index that a key names, if it is one: "3", but not "03"
 * nor "-1" *)
val index_of_key : string -> int option

(* a value as a property's key: 3 is "3", 1.5 is "1.5", and anything
 * else is its string *)
val key_of : Js_value.value -> string

(* an object's prototype: its own, or else its kind's (an array's is
 * Array.prototype), with Object.prototype last and nothing after it *)
val proto_of : Js_builtins.protos -> Js_value.obj -> Js_value.obj option

(* [get protos v k] is v.k, looked for up the prototypes. It raises a
 * TypeError if [v] is undefined or null. *)
val get : Js_builtins.protos -> Js_value.value -> string -> Js_value.value

(* k in o: whether o or its prototypes have k *)
val has : Js_builtins.protos -> Js_value.obj -> string -> bool

(* v instanceof F: whether F.prototype is in v's chain *)
val instance_of : Js_builtins.protos -> Js_value.value -> Js_value.value -> bool

(* v.k = x, on the object itself (an array may be grown, or its length
 * set; a host object is asked). It is lost on a primitive, and it
 * raises a TypeError on undefined or null. *)
val set : Js_value.value -> string -> Js_value.value -> unit

(* the keys that a for (k in v) goes through *)
val enumerable_keys : Js_value.value -> string list

(* the name of the property that marks a prototype as the browser's own
 * (Node.prototype, HTMLElement.prototype...). On a host object, what a
 * page's class has under a name comes before what the browser answers,
 * and the page's prototypes are those above the first marked one. *)
val dom_mark : string
