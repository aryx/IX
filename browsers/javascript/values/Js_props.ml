(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/values/Js_props.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_props.mli *)
open Js_value

(* the array index a key names, if it is one: "3", not "03" nor "-1" *)
let index_of_key (k : string) : int option =
  (* a digit first: most keys are names, not to be read as numbers *)
  if k = "" || k.[0] < '0' || k.[0] > '9' then None
  else match int_of_string_opt k with Some i when i >= 0 && string_of_int i = k -> Some i | _ -> None

let key_of (v : value) : string = match v with Symbol k -> k | Number f when Float.is_integer f && f >= 0. -> Js_ast.number_to_string f | v -> to_string v

(* an object's prototype: its own, else its kind's (an array's
 * Array.prototype...), Object.prototype last, and nothing after it *)
let rec proto_of (ps : Js_builtins.protos) (o : obj) : obj option =
  match o.proto with
  | Some p -> Some p
  | None -> (
      let p = ps in
      if o == p.objects then None
      else
        match o.kind with
        | Array _ -> Some p.arrays
        | Closure _ | Host_function _ -> Some p.functions
        | Regexp _ -> Some p.regexps
        | Host_object _ | Accessor _ -> None
        | Proxy (t, _) -> proto_of ps t
        (* an error has its kind's prototype: TypeError.prototype,
         * itself under Error.prototype *)
        | Plain -> ( match Js_builtins.error_proto p.errors o with Some e -> Some e | None -> Some p.objects))

(* a property: the object's own, else up its prototypes' chain; a
 * function's prototype made when first asked for, {constructor: f} *)
(* the mark of a prototype that is the browser's own (Node.prototype,
 * HTMLElement.prototype...): a property of that name, not enumerated *)
let dom_mark = "@@dom"

let rec from_chain (ps : Js_builtins.protos) (o : obj) (k : string) : value =
  match get_own o k with
  | Some v -> v
  | None -> (
      match (o.kind, k) with
      | (Closure _ | Host_function _), "prototype" ->
          let p = new_object () in
          set_own p "constructor" (Object o);
          hide p "constructor";
          set_own o "prototype" (Object p);
          hide o "prototype";
          Object p
      (* a function's name, and how many parameters it declares *)
      | Closure { func; _ }, "name" -> String ((match func.name with Some v_ -> v_ | None -> ""))
      | Closure { func; _ }, "length" -> Number (float_of_int (List.length func.params))
      | Host_function (name, _), "name" -> String name
      | Host_object h, _ -> (
          (* what the page's own class has of that name comes first (a
           * custom element's method named as a property the browser
           * has: Polymer's async): its prototypes, down to the
           * browser's own, which are marked *)
          let rec page (p : obj option) : value option =
            match p with
            | Some p when get_own p dom_mark = None -> ( match get_own p k with Some v -> Some v | None -> page p.proto)
            | _ -> None
          in
          match page o.proto with
          (* but what a script put on the object itself comes before its class's *)
          | Some v -> if h.get (Js_builtins.own_query ^ k) = Bool true then h.get k else v
          | None -> (
              let found = match (h.get k, o.proto) with Undefined, Some p -> from_chain ps p k | v, _ -> v in
              (match (found, !missing) with Undefined, Some told -> told h.class_name k | _ -> ());
              found))
      | _ -> ( match proto_of ps o with Some p -> from_chain ps p k | None -> Undefined))

let rec get (ps : Js_builtins.protos) (target : value) (k : string) : value =
  match target with
  (* o.__proto__: its prototype (Object.getPrototypeOf, as a property) *)
  | Object o when k = "__proto__" && get_own o k = None -> ( match proto_of ps o with Some p -> Object p | None -> Null)
  | Object { kind = Proxy (t, _); _ } -> get ps (Object t) k
  | Undefined | Null -> throw "TypeError" (Printf.sprintf "Cannot read properties of %s (reading '%s')" (to_string target) k)
  (* a rope's length is known; anything else of it is of its text *)
  | Rope r -> if k = "length" then Number (float_of_int r.units) else get ps (String (flatten r)) k
  | String s -> (
      match (k, index_of_key k) with
      (* in UTF-16's units, as a script counts (Js_utf16) *)
      | "length", _ -> Number (float_of_int (Js_utf16.length s))
      | _, Some i -> if i < Js_utf16.length s then String (Js_utf16.sub s i (i + 1)) else Undefined
      | _ -> from_chain ps ps.strings k)
  | Object ({ kind = Array a; _ } as o) -> (
      match (k, index_of_key k) with
      | "length", _ -> Number (float_of_int a.length)
      | _, Some i -> if i < a.length then a.elements.(i) else Undefined
      | _ -> from_chain ps o k)
  (* a host object's own answer, else what the prototype it
   * was given has (an element's: Element.prototype, and what a library
   * added to it) *)
  | Object o -> from_chain ps o k
  | Number _ -> from_chain ps ps.numbers k
  | Symbol _ -> (
      match k with
      | "description" -> let s = to_string target in String (String.sub s 7 (String.length s - 8))
      | "toString" -> host_function k (fun ~this:_ _ -> String (to_string target))
      | _ -> from_chain ps ps.objects k)
  (* true.toString(), which a setting read as text asks *)
  | Bool b -> (
      match k with
      | "toString" -> host_function k (fun ~this:_ _ -> String (string_of_bool b))
      | "valueOf" -> host_function k (fun ~this:_ _ -> target)
      (* the rest is every object's: (!o).hasOwnProperty(k), false for
       * any k, which a minifier writes *)
      | _ -> from_chain ps ps.objects k)

(* whether an object has a property, its own or its prototypes': k in o *)
let rec has (ps : Js_builtins.protos) (o : obj) (k : string) : bool =
  get_own o k <> None
  ||
  match o.kind with
  | Proxy (t, _) -> has ps t k
  | Array a -> k = "length" || (match index_of_key k with Some i -> i < a.length | None -> false) || inherited ps o k
  (* what the host has, or its prototypes: a getter there that gives
   * null ("oninput" in el: how a library asks whether an event is known) *)
  | Host_object h -> h.get k <> Undefined || (match o.proto with Some p -> has ps p k | None -> false)
  | _ -> inherited ps o k

and inherited (ps : Js_builtins.protos) (o : obj) (k : string) : bool = match proto_of ps o with Some p -> has ps p k | None -> false

(* the keys for (k in v) goes through: an array's indices, a string's;
 * an object's own, in the order they were set, then those of the
 * prototypes it was given (not the built-in ones', whose methods do
 * not show; nor a prototype's "constructor") *)
let enumerable_keys (v : value) : string list =
  let rec chain (o : obj) (seen : string list) : string list =
    (* not a symbol's key ("@@...": Js_globals) *)
    let symbol k = String.length k >= 2 && k.[0] = '@' && k.[1] = '@' in
    let own = List.filter (fun k -> not (List.mem k seen || symbol k)) (keys o) in
    own @ match o.proto with Some p -> List.filter (( <> ) "constructor") (chain p (seen @ own)) | None -> []
  in
  match (match v with Object o -> Object (Js_value.target o) | v -> v) with
  | Object ({ kind = Array a; _ } as o) -> List.init a.length string_of_int @ chain o []
  | Object { kind = Host_object _; _ } -> []
  | Object o -> chain o []
  | String s -> List.init (Js_utf16.length s) string_of_int
  | _ -> []

(* whether F's prototype is in v's chain: v instanceof F *)
let instance_of (ps : Js_builtins.protos) (v : value) (f : value) : bool =
  match (v, get ps f "prototype") with
  | Object o, Object p ->
      let rec up (x : obj) = match proto_of ps x with Some q -> q == p || up q | None -> false in
      up o
  (* a symbol is one of Symbol's *)
  | Symbol _, _ -> ( match f with Object { kind = Host_function ("Symbol", _); _ } -> true | _ -> false)
  | _ -> false

let rec set (target : value) (k : string) (v : value) : unit =
  (* what is kept is a String, never a rope *)
  let v = flat v in
  match target with
  (* o.__proto__ = p: its prototype, of any object (a browser's own
   * too: how a polyfill makes a fragment one of its ShadowRoots) *)
  | Object o when k = "__proto__" -> ( match v with Object p -> o.proto <- Some p | Null -> o.proto <- None | _ -> ())
  | Object { kind = Proxy (t, _); _ } -> set (Object t) k v
  | Undefined | Null -> throw "TypeError" (Printf.sprintf "Cannot set properties of %s (setting '%s')" (to_string target) k)
  | Object ({ kind = Array a; _ } as o) -> (
      let grow n =
        if n > Array.length a.elements then (
          let bigger = Array.make (max n (2 * Array.length a.elements)) Undefined in
          Array.blit a.elements 0 bigger 0 a.length;
          a.elements <- bigger)
      in
      match (k, index_of_key k) with
      | "length", _ ->
          let n = int_of_float (to_number v) in
          grow n;
          for i = a.length to n - 1 do a.elements.(i) <- Undefined done;
          a.length <- n
      | _, Some i ->
          grow (i + 1);
          for j = a.length to i - 1 do a.elements.(j) <- Undefined done;
          a.elements.(i) <- v;
          a.length <- max a.length (i + 1)
      | _ -> set_own o k v)
  | Object { kind = Host_object h; _ } -> h.set k v
  | Object o -> set_own o k v
  (* a property of a primitive: lost, as JavaScript loses it *)
  | Bool _ | Number _ | String _ | Rope _ | Symbol _ -> ()
