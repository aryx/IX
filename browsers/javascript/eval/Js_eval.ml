(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/eval/Js_eval.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_eval.mli *)
open Js_value
module A = Js_ast

type t = {
  globals : scope;
  mutable protos : Js_builtins.protos option; (* set once the built-ins are *)
  mutable promises : Js_promise.t option; (* the same: the jobs waiting *)
  mutable line : int; (* of the statement running: an error's *)
  mutable steps : int; (* left in this run's budget *)
  mutable budget : int;
  mutable seconds : float; (* a run's time at most, if steps are not the limit (a page's): infinity, none *)
  mutable deadline : float;
  mutable depth : int; (* of the calls *)
  mutable generators : generating list; (* those whose body is running, the innermost first *)
  (* import("m") in the module whose address is [base]: a promise of
   * its names (Js_module's, once there are modules) *)
  mutable importer : (base:string -> string -> value) option;
  global_this : A.place; (* opti: where globalThis is, in the globals *)
}

(* a generator between its body and who calls next(): what the body
 * gave last, what it is given back *)
and generating = { mutable out : out; mutable sent : sent }
and out = Yielded of value | Ended of value | Failed of value
and sent = Sent of value | Thrown of value | Returned of value

type error = { line : int; message : string }

(* how a statement ended *)
type outcome = Normal | Return of value | Break of string option | Continue of string option

let max_depth = 2_000

(* a debugger's watchpoint, for a variable that changes and should not:
 * __watch(() => 0, "t") in a script watches the t that closure sees;
 * each call entered or left after it changed says so, once a change
 * (the function then running is where to look) *)
let watched : (string * binding * value) option ref = ref None

let watch_check (where : string) : unit =
  match !watched with
  | Some (name, b, was) when b.value != was ->
      !Js_value.say (Printf.sprintf "watch: %s changed to %s, seen %s" name (display b.value) where);
      watched := Some (name, b, b.value)
  | _ -> ()

(* how many more calls to say, as an error leaves them (JS_STACK) *)
(* __trace(n): how many calls are still to be said *)
let tracing = ref 0

let unwinding = Js_value.unwinding

(* generator.return(v): the body left from its yield, its finally
 * blocks run on the way *)
exception Generator_return of value

(* a?.b with a null or undefined: the chain it is in ends, undefined *)
exception Short_circuit

(* get k() and set k(v) of the same k are one property of [o]: the
 * getter or the setter given, the other kept *)
let define_accessor (o : obj) (k : string) ~(getter : value option) ~(setter : value option) : unit =
  let g, st = match get_own o k with Some (Object { kind = Accessor (g, st); _ }) -> (g, st) | _ -> (Undefined, Undefined) in
  set_own o k (Object { (new_object ()) with kind = Accessor ((match getter with Some v_ -> v_ | None -> g), (match setter with Some v_ -> v_ | None -> st)) })

(*****************************************************************************)
(* Scopes *)
(*****************************************************************************)

(* Js_scope's: a scope under another, a name looked for from a scope
 * up (by its name alone; [find] remembers where it was), a name
 * declared *)
let new_scope = Js_scope.nested
let lookup = Js_scope.lookup
let find = Js_scope.find
let declare = Js_scope.declare
let hoist = Js_frame.hoist

(* the address of the module the code is in ("" in a script): a name
 * of its scope that no script can write *)
let module_url (s : scope) : string = match lookup s "%module" with Some { value = String url; _ } -> url | _ -> ""

(*****************************************************************************)
(* Properties *)
(*****************************************************************************)

let protos (t : t) : Js_builtins.protos = Option.get t.protos

(* an object's properties and the operators are Js_props' and
 * Js_operators'; here with the interpreter's prototypes *)
let has (t : t) = Js_props.has (protos t)
let instance_of (t : t) = Js_props.instance_of (protos t)
let key_of = Js_props.key_of
let enumerable_keys = Js_props.enumerable_keys

open Js_operators

(* "x", "o.m": what a TypeError names *)
let rec describe (e : A.expr) : string =
  match e with
  | Name x | Local (x, _) -> x
  | This -> "this"
  | Member (o, x) -> describe o ^ "." ^ x
  (* o[k] by a name or a constant says which: in a script made small
   * (t[e] is not a function), the one thing to look for *)
  | Index (o, (Name k | Local (k, _))) -> describe o ^ "[" ^ k ^ "]"
  | Index (o, String k) -> Printf.sprintf "%s[%S]" (describe o) k
  | Index (o, Number n) -> Printf.sprintf "%s[%s]" (describe o) (A.number_to_string n)
  | Index (o, _) -> describe o ^ "[...]"
  | Call (f, _) -> describe f ^ "(...)"
  (* anything else as it was written, cut short: to be looked for in the script *)
  | e -> let text = A.expr_to_string e in if String.length text > 70 then String.sub text 0 67 ^ "..." else text

(*****************************************************************************)
(* Expressions *)
(*****************************************************************************)

let tick (t : t) : unit =
  t.steps <- t.steps - 1;
  if t.steps < 0 then throw "RangeError" "the script ran too long (a loop that never ends?)";
  (* and by the clock, looked at every million steps: a page's run is
   * allowed long (an application's start), not for ever *)
  if t.steps land 0xFFFFF = 0 && !Js_value.wall_clock () > t.deadline then throw "RangeError" "the script ran too long (a loop that never ends?)"

(* a statement begun: its line, for an error; one step of the budget *)
let step (t : t) (line : int) : unit =
  t.line <- line;
  tick t

(* opti: who compiles a function's body, if somebody does: Js_compile,
 * which is after this module and says so when the program starts *)
let compiler : (t -> A.func -> scope -> value -> value) option ref = ref None

(* eval(text) written so, by that name: a "direct" eval, whose text is
 * run where the call is -- it sees the names of the function calling
 * it (set below, where a program's run is) *)
let direct_eval : (t -> scope -> value -> string -> value) ref = ref (fun _ _ _ _ -> Undefined)

let rec eval_expr (t : t) (s : scope) (this : value) (e : A.expr) : value =
  match e with
  | Number f -> Number f
  | String x -> String x
  | Bool b -> Bool b
  | Null -> Null
  | This -> this
  | Name x -> (
      match if s.in_with then with_subject t s x else None with
      | Some o -> get t o x
      | None -> ( match lookup s x with Some b -> b.value | None -> throw "ReferenceError" (x ^ " is not defined")))
  (* opti: the name looked for where it was last found (Js_quicken,
   * Js_scope.find); in a with, as a Name *)
  | Local (x, _) when s.in_with -> eval_expr t s this (Name x)
  | Local (x, p) -> ( match find s x p with Some b -> b.value | None -> throw "ReferenceError" (x ^ " is not defined"))
  | Array es -> Object (new_array (eval_list t s this es))
  | Spread _ -> throw "SyntaxError" "... is for an array's items or a call's arguments"
  | Object props ->
      let o = new_object () in
      let key (k : A.key) = match k with Key k -> k | Computed e -> key_of (eval_expr t s this e) in
      let accessor = define_accessor o in
      List.iter
        (fun (pr : A.property) ->
          match pr with
          | Prop (k, v) -> set_own o (key k) (eval_expr t s this v)
          | Getter (k, f) -> accessor (key k) ~getter:(Some (closure s this f)) ~setter:None
          | Setter (k, f) -> accessor (key k) ~getter:None ~setter:(Some (closure s this f))
          (* ...o: its own properties, copied *)
          | Spread_prop e -> (
              match eval_expr t s this e with
              | Object ({ kind = Array a; _ } as src) ->
                  Array.iteri (fun i v -> if i < a.length then set_own o (string_of_int i) v) a.elements;
                  List.iter (fun k -> set_own o k (get t (Object src) k)) (keys src)
              (* a proxy's: the keys its handler says (ownKeys), else its target's *)
              | Object ({ kind = Proxy (tg, h); _ } as src) ->
                  let ks =
                    match trap t h "ownKeys" with
                    | Some f -> List.filter_map (fun k -> match k with String k -> Some k | _ -> None) (items_of t (call_value t f ~this:(Object h) [ Object tg ]))
                    | None -> keys (Js_value.target tg)
                  in
                  List.iter (fun k -> set_own o k (get t (Object src) k)) ks
              | Object src -> List.iter (fun k -> set_own o k (get t (Object src) k)) (keys src)
              | String str -> String.iteri (fun i c -> set_own o (string_of_int i) (String (String.make 1 c))) str
              | Rope r -> String.iteri (fun i c -> set_own o (string_of_int i) (String (String.make 1 c))) (flatten r)
              | _ -> ()))
        props;
      Object o
  | Function f -> closure s this f
  | Class c -> make_class t s this c
  (* super(a): the parent's constructor, on this object; then this
   * class's fields. A host constructor (Error) gives an object of its
   * own: what it holds is this object's *)
  | Super_call args ->
      let hidden x = match lookup s x with Some b -> b.value | None -> Undefined in
      (match (call_value t (hidden "%super") ~this (eval_list t s this args), this) with
      | Object made, Object self when made != self ->
          List.iter
            (fun k ->
              set_own self k (Option.get (get_own made k));
              if not (shows made k) then hide self k)
            (all_keys made)
      | _ -> ());
      ignore (call_value t (hidden "%init") ~this []);
      Undefined
  | Super_member k -> (
      match lookup s "%home" with
      | Some { value = Object { proto = Some parent; _ }; _ } -> get t (Object parent) k
      | _ -> Undefined)
  | Opt e -> ( match eval_expr t s this e with Undefined | Null -> raise Short_circuit | v -> v)
  | Optional e -> ( try eval_expr t s this e with Short_circuit -> Undefined)
  | Await e -> Js_promise.await (Option.get t.promises) (eval_expr t s this e)
  | Import_call e -> (
      let spec = to_string (eval_expr t s this e) in
      match t.importer with
      | Some (import : base:string -> string -> value) -> import ~base:(module_url s) spec
      | None -> throw "TypeError" ("import(\"" ^ spec ^ "\"): there are no modules here"))
  | Import_meta ->
      let meta = new_object () in
      set_own meta "url" (String (module_url s));
      Object meta
  (* tag`a${x}b`: tag(["a", "b"], x), the strings' array with itself
   * as its raw (the escapes are read already: an approximation) *)
  | Tagged (tag, strings, es) ->
      let fn, self = match tag with Member (o, k) -> let o = eval_expr t s this o in (get t o k, o) | tag -> (eval_expr t s this tag, Undefined) in
      let parts = new_array (List.map (fun x -> String x) strings) in
      set_own parts "raw" (Object parts);
      call_value t fn ~this:self (Object parts :: List.map (eval_expr t s this) es)
  | Yield (false, e) -> yield t (match e with Some e -> eval_expr t s this e | None -> Undefined)
  (* yield* xs: each of xs yielded *)
  | Yield (true, e) ->
      iterate t (match e with Some e -> eval_expr t s this e | None -> Undefined) (fun v -> ignore (yield t v); true);
      Undefined
  (* a ||= b: assigned only if a is falsy; &&=, ??= the same of && and ?? *)
  | Assign ((("&&=" | "||=" | "??=") as op), target, v) ->
      let old = eval_expr t s this target in
      let wanted = match op with "&&=" -> truthy old | "||=" -> not (truthy old) | _ -> old = Undefined || old = Null in
      if wanted then (let v = eval_expr t s this v in assign t s this target v; v) else old
  | Unary (op, x) -> (
      match op with
      (* typeof of an undeclared name is "undefined", not an error *)
      | "typeof" -> (
          match x with
          | Name n when lookup s n = None && not (s.in_with && with_subject t s n <> None) -> String "undefined"
          | Local (n, _) when s.in_with -> eval_expr t s this (Unary (op, Name n))
          | Local (n, p) when find s n p = None -> String "undefined"
          | _ -> String (typeof (eval_expr t s this x)))
      | "!" -> Bool (not (truthy (eval_expr t s this x)))
      | "-" -> Number (-.to_number (eval_expr t s this x))
      | "~" -> of_int32 (Int32.lognot (to_int32 (eval_expr t s this x)))
      | "void" -> ignore (eval_expr t s this x); Undefined
      (* delete o.k: the property gone from the object itself *)
      | "delete" -> (
          let rec remove o k =
            match o with
            | Object { kind = Proxy (tg, h); _ } -> (
                match trap t h "deleteProperty" with Some f -> ignore (call_value t f ~this:(Object h) [ Object tg; String k ]) | None -> remove (Object tg) k)
            | Object o ->
                o.props <- List.filter (fun (k', _) -> k' <> k) o.props;
                (* and what a host keeps of it itself (an element's property a script set) *)
                (match o.kind with Host_object h -> h.set (Js_builtins.own_query ^ k) Undefined | _ -> ())
            | _ -> ()
          in
          match x with
          | Member (o, k) -> remove (eval_expr t s this o) k; Bool true
          | Index (o, k) -> let o = eval_expr t s this o in remove o (key_of (eval_expr t s this k)); Bool true
          | _ -> Bool true)
      | _ -> Number (to_number (eval_expr t s this x)))
  | Update (op, prefix, target) ->
      let old = to_number (eval_expr t s this target) in
      let now = if op = "++" then old +. 1. else old -. 1. in
      assign t s this target (Number now);
      Number (if prefix then now else old)
  | Binary ("instanceof", a, f) ->
      let a = eval_expr t s this a in
      Bool (instance_of t a (eval_expr t s this f))
  | Binary ("in", k, o) -> (
      let k = key_of (eval_expr t s this k) in
      match eval_expr t s this o with
      | Object _ as o -> Bool (has_property t o k)
      | v -> throw "TypeError" (Printf.sprintf "Cannot use 'in' operator to search for '%s' in %s" k (display v)))
  | Comma (a, b) -> ignore (eval_expr t s this a); eval_expr t s this b
  (* `a${x}b`: the strings and the values, as strings, one after the other *)
  | Template (strings, es) ->
      let values = List.map (fun e -> to_string (eval_expr t s this e)) es in
      let rec weave strings values = match (strings, values) with str :: rest, v :: vs -> str :: v :: weave rest vs | strings, _ -> strings in
      String (String.concat "" (weave strings values))
  | Binary (op, a, b) ->
      let a = eval_expr t s this a in
      arithmetic op a (eval_expr t s this b)
  | Regex (source, flags) -> (
      match Js_regexp.compile source flags with
      | Ok re -> Js_builtins.regexp_value (protos t).regexps re
      | Error why -> throw "SyntaxError" ("Invalid regular expression: /" ^ source ^ "/: " ^ why))
  (* new F(a): an object whose prototype is F.prototype, F called with it
   * as this; what F returns instead if it is an object (a host
   * constructor's: Date, URL) *)
  | New (f, args) ->
      let fn = eval_expr t s this f in
      let args = eval_list t s this args in
      (match fn with Object { kind = Closure _ | Host_function _ | Proxy _; _ } -> () | _ -> throw "TypeError" (describe f ^ " is not a constructor"));
      let o = new_object () in
      (match get t fn "prototype" with Object p -> o.proto <- Some p | _ -> ());
      (match call_value t fn ~this:(Object o) args with Object _ as r -> r | _ -> Object o)
  | Logical ("&&", a, b) -> let v = eval_expr t s this a in if truthy v then eval_expr t s this b else v
  | Logical ("??", a, b) -> ( match eval_expr t s this a with Undefined | Null -> eval_expr t s this b | v -> v)
  | Logical (_, a, b) -> let v = eval_expr t s this a in if truthy v then v else eval_expr t s this b
  (* o.k = v, o[k] = v: o (and k) first, then v, as written --
   * "(b = {...}).x = b.y", in a minified jQuery, needs b made before
   * b.y is read *)
  | Assign ("=", Member (o, k), v) ->
      let o = eval_expr t s this o in
      let v = eval_expr t s this v in
      put t o k v;
      v
  | Assign ("=", Index (o, k), v) ->
      let o = eval_expr t s this o in
      let k = eval_expr t s this k in
      let v = eval_expr t s this v in
      put_item t o k v;
      v
  | Assign ("=", target, v) ->
      let v = eval_expr t s this v in
      assign t s this target v;
      v
  | Assign (op, target, v) ->
      let old = eval_expr t s this target in
      (* "+=" is "+", ">>>=" is ">>>" *)
      let v = arithmetic (String.sub op 0 (String.length op - 1)) old (eval_expr t s this v) in
      assign t s this target v;
      v
  | Conditional (c, a, b) -> if truthy (eval_expr t s this c) then eval_expr t s this a else eval_expr t s this b
  | Member (o, k) -> get t (eval_expr t s this o) k
  | Index (o, k) ->
      let o = eval_expr t s this o in
      item t o (eval_expr t s this k)
  (* eval(text), the engine's own eval called by its name: its text in
   * this scope (an anti-abuse script of Google's is a closure whose
   * machine evaluates pieces of text naming the closure's own
   * functions: run in the global scope, as every eval was, none was
   * defined) *)
  | Call (((Name "eval" | Local ("eval", _)) as f), [ arg ]) -> (
      let fn = eval_expr t s this f in
      match (fn, eval_expr t s this arg) with
      | Object { kind = Host_function ("eval", _); _ }, String text -> !direct_eval t s this text
      | Object { kind = Closure _ | Host_function _ | Proxy _; _ }, v -> call_value t fn ~this:Undefined [ v ]
      | _ -> throw "TypeError" "eval is not a function")
  | Call (f, args) ->
      (* a method call: this is the object the function was read from *)
      let fn, self =
        match f with
        | Member (o, k) -> let o = eval_expr t s this o in (get t o k, o)
        | Index (o, k) ->
            let o = eval_expr t s this o in
            let key = eval_expr t s this k in
            let fn = item t o key in
            (* o[k]() with no function there: the key said, which the text does not *)
            (match (fn, k) with
            | Object { kind = Closure _ | Host_function _ | Proxy _; _ }, _ | _, (String _ | Number _) -> ()
            | _ -> throw "TypeError" (Printf.sprintf "%s is not a function (the key: %s)" (describe f) (display key)));
            (fn, o)
        (* o.m?.(): the method, if there is one, still on o *)
        | Opt (Member (o, k)) -> (
            let o = eval_expr t s this o in
            match get t o k with Undefined | Null -> raise Short_circuit | fn -> (fn, o))
        (* super.m(): the parent's m, on this *)
        | Super_member _ -> (eval_expr t s this f, this)
        | _ -> (eval_expr t s this f, Undefined)
      in
      let args = eval_list t s this args in
      (match fn with Object { kind = Closure _ | Host_function _ | Proxy _; _ } -> () | _ -> throw "TypeError" (describe f ^ " is not a function"));
      call_value t fn ~this:self args

(* class A extends B { ... }: a constructor function whose prototype
 * has the methods, and B's prototype behind it; the class's static
 * members on the function itself, B behind it. Its constructor and
 * methods are made in a scope that knows the parent (%super), the
 * prototype (%home: super.m is looked for behind it) and how to set
 * the fields of a new object (%init) *)
and make_class (t : t) (s : scope) (this : value) (c : A.class_) : value =
  let cs = Js_scope.strict s in
  let proto = new_object () in
  let parent = Option.map (eval_expr t s this) c.parent in
  (match parent with
  | None | Some Null -> ()
  | Some (Object { kind = Closure _ | Host_function _; _ } as pv) -> ( match get t pv "prototype" with Object pp -> proto.proto <- Some pp | _ -> ())
  | Some v -> throw "TypeError" (Printf.sprintf "Class extends value %s is not a constructor or null" (display v)));
  let key (k : A.key) = match k with Key k -> k | Computed e -> key_of (eval_expr t cs this e) in
  let fields = List.filter_map (fun (m : A.member) -> match m.what with Field e when not m.static -> Some (key m.key, e) | _ -> None) c.members in
  let init =
    host_function "fields" (fun ~this _ ->
        List.iter (fun (k, e) -> put t this k (match e with Some e -> eval_expr t cs this e | None -> Undefined)) fields;
        Undefined)
  in
  declare cs "%super" ~constant:true ((match parent with Some v_ -> v_ | None -> Undefined));
  declare cs "%home" ~constant:true (Object proto);
  declare cs "%init" ~constant:true init;
  let stmt e : A.stmt = { line = t.line; stmt = Expr e } in
  (* its fields first (a class of its own), or by super() (one that
   * extends); with no constructor written: the parent's, called with
   * what it was given *)
  let ctor : A.func =
    match (c.ctor, c.parent) with
    | Some f, Some _ -> f
    | Some f, None -> { f with body = stmt (A.Call (A.Member (A.Name "%init", "call"), [ A.This ])) :: f.body }
    | None, None ->
        { name = c.class_name; params = []; rest = None; body = [ stmt (A.Call (A.Member (A.Name "%init", "call"), [ A.This ])) ]; arrow = false; generator = false; async = false; frame = None; own_name = false; text = None }
    | None, Some _ ->
        { name = c.class_name; params = []; rest = Some (A.Bind "args"); body = [ stmt (A.Super_call [ A.Spread (A.Name "args") ]) ]; arrow = false; generator = false; async = false; frame = None; own_name = false; text = None }
  in
  (* opti: a constructor made here is quickened as the written ones were *)
  let ctor = if ctor.frame = None && Js_scope.slotted s then Js_quicken.func ctor else ctor in
  let made = closure cs this { ctor with name = c.class_name } in
  let f = match made with Object f -> f | _ -> assert false in
  set_own f "prototype" (Object proto);
  hide f "prototype";
  set_own proto "constructor" made;
  hide proto "constructor";
  (match parent with Some (Object pc) -> f.proto <- Some pc | _ -> ());
  Option.iter (fun name -> declare cs name ~constant:true made) c.class_name;
  (* a static member's home is the class itself: its super.m is the
   * parent class's m, not the parent prototype's *)
  let statics = Js_scope.nested cs in
  declare statics "%home" ~constant:true made;
  (* the methods and accessors first, all of them; then the static
   * fields and blocks, in the order written (ES2022): a block that
   * decorates an accessor, written between its getter and its setter,
   * finds both *)
  List.iter
    (fun (m : A.member) ->
      let target = if m.static then f else proto in
      let cs = if m.static then statics else cs in
      match m.what with
      (* a class's methods and accessors do not show (for-in, Object.keys) *)
      | Method fn -> let k = key m.key in set_own target k (closure cs this fn); hide target k
      | Get fn -> let k = key m.key in define_accessor target k ~getter:(Some (closure cs this fn)) ~setter:None; hide target k
      | Set fn -> let k = key m.key in define_accessor target k ~getter:None ~setter:(Some (closure cs this fn)); hide target k
      | Field _ | Static_block _ -> ())
    c.members;
  List.iter
    (fun (m : A.member) ->
      match m.what with
      | Field e when m.static -> set_own f (key m.key) (match e with Some e -> eval_expr t statics made e | None -> Undefined)
      | Static_block body -> ignore (exec_block_at ~top:true t (new_scope statics) made body)
      | _ -> ())
    c.members;
  made

(* an array's items or a call's arguments: each one's value, a ...xs
 * each of xs' *)
and eval_list (t : t) (s : scope) (this : value) (es : A.expr list) : value list =
  match es with
  | [] -> []
  | Spread x :: rest -> let items = items_of t (eval_expr t s this x) in items @ eval_list t s this rest
  | e :: rest -> let v = eval_expr t s this e in v :: eval_list t s this rest

(* what a for-of, a ...spread or an array pattern goes through, one
 * item at a time, [f] saying whether to go on: an array's items, a
 * string's characters; else the iteration protocol (ES2015) -- the
 * object's [Symbol.iterator]() gives an iterator, whose next() gives
 * { value, done } each time; stopped early, its return() is called *)
and iterate (t : t) (v : value) (f : value -> bool) : unit =
  let rec each (l : value list) = match l with x :: rest -> if f x then each rest | [] -> () in
  match v with
  (* a proxy of an array that answers for it (a get trap): its length
   * and items asked of the proxy, not read in the array behind (a
   * template's arguments: a proxy over an empty array) *)
  | Object { kind = Proxy (tg, h); _ } when (match (Js_value.target tg).kind with Array _ -> true | _ -> false) && trap t h "get" <> None ->
      let n = match get t v "length" with Number n when n > 0. -> int_of_float n | _ -> 0 in
      let rec from i = if i < n && f (get t v (string_of_int i)) then from (i + 1) in
      from 0
  | Object ({ kind = Array _ | Proxy _; _ } as o) when (match (Js_value.target o).kind with Array _ -> true | _ -> false) -> each (array_items o)
  (* a string's characters, a pair of halves as one (for-of, a spread, Array.from) *)
  | String str -> each (List.map (fun cp -> String (Js_utf16.of_code_point cp)) (Js_utf16.code_points str))
  | Rope r -> iterate t (String (flatten r)) f
  | Object _ -> (
      match get t v "@@iterator" with
      | Object { kind = Closure _ | Host_function _; _ } as make -> (
          match call_value t make ~this:v [] with
          (* an array given at once (a Map's entries here) *)
          | Object { kind = Array _; _ } as items -> iterate t items f
          | it ->
              let next = get t it "next" in
              let rec go () =
                let r = call_value t next ~this:it [] in
                if not (truthy (get t r "done")) then
                  if f (get t r "value") then go ()
                  else match get t it "return" with Object { kind = Closure _ | Host_function _; _ } as stop -> ignore (call_value t stop ~this:it []) | _ -> ()
              in
              go ())
      | _ -> throw "TypeError" (display v ^ " is not iterable"))
  | v -> throw "TypeError" (display v ^ " is not iterable")

and items_of (t : t) (v : value) : value list =
  let items = ref [] in
  iterate t v (fun x -> items := x :: !items; true);
  List.rev !items

(* yield v, in a generator's body: v given to who called next(), the
 * body stopped until the next one; what that next() was given *)
and yield (t : t) (v : value) : value =
  match t.generators with
  | [] -> throw "SyntaxError" "yield is only valid in generator functions"
  | g :: _ -> (
      g.out <- Yielded v;
      Js_coroutine.suspend ();
      match g.sent with
      | Sent v -> v
      | Thrown e -> raise (Throw e)
      | Returned v -> raise (Generator_return v))

(* a generator's call: its body a coroutine not started yet, and the
 * iterator that runs it a yield at a time -- next(v), return(v),
 * throw(e), and itself as its own [Symbol.iterator]() *)
and generator (t : t) (body : unit -> value) : value =
  let g = { out = Yielded Undefined; sent = Sent Undefined } in
  let ended = ref false and started = ref false in
  let run () =
    g.out <-
      (match body () with
      | v -> Ended v
      | exception Generator_return v -> Ended v
      | exception Throw e -> Failed e
      | exception Stack_overflow -> Failed (error "RangeError" "Maximum call stack size exceeded"));
    ended := true
  in
  let co = Js_coroutine.create run in
  let result v finished =
    let o = new_object () in
    set_own o "value" v;
    set_own o "done" (Bool finished);
    Object o
  in
  let resume (what : sent) : value =
    if !ended then (match what with Thrown e -> raise (Throw e) | Returned v -> result v true | Sent _ -> result Undefined true)
    else if (not !started) && (match what with Sent _ -> false | _ -> true) then (
      (* stopped before it began: nothing of its body runs *)
      ended := true;
      match what with Thrown e -> raise (Throw e) | Returned v -> result v true | Sent _ -> result Undefined true)
    else (
      started := true;
      g.sent <- what;
      t.generators <- g :: t.generators;
      Js_coroutine.resume co;
      t.generators <- List.tl t.generators;
      match g.out with Yielded v -> result v false | Ended v -> result v true | Failed e -> raise (Throw e))
  in
  let o = new_object () in
  let self = Object o in
  let arg args = match args with v :: _ -> v | [] -> Undefined in
  set_own o "next" (host_function "next" (fun ~this:_ args -> resume (Sent (arg args))));
  set_own o "return" (host_function "return" (fun ~this:_ args -> resume (Returned (arg args))));
  set_own o "throw" (host_function "throw" (fun ~this:_ args -> resume (Thrown (arg args))));
  set_own o "@@iterator" (host_function "[Symbol.iterator]" (fun ~this:_ _ -> self));
  self

(* o.k: the property, or what its getter gives *)
and get (t : t) (target : value) (k : string) : value =
  match target with
  (* a proxy: its handler's get(target, key, receiver), else the target's *)
  | Object { kind = Proxy (tg, h); _ } -> (
      match trap t h "get" with Some f -> call_value t f ~this:(Object h) [ Object tg; String k; target ] | None -> get t (Object tg) k)
  | _ -> (
      match Js_props.get (protos t) target k with
      | Object { kind = Accessor (getter, _); _ } -> if getter = Undefined then Undefined else call_value t getter ~this:target []
      | v -> v)

(* o[k], o[k] = v: the property whose key is k as a string *)
and item_simple (t : t) (o : value) (k : value) : value = get t o (key_of k)
and put_item_simple (t : t) (o : value) (k : value) (v : value) : unit = put t o (key_of k) v

(* opti: an array's item that is there, by a number: read and written
 * in place -- where the simple way writes the number as a string
 * ("3"), and Js_props reads the string back as a number. 1M reads:
 * 1,300 ms to 470 *)
and item_opti (t : t) (o : value) (k : value) : value =
  match (o, k) with
  | Object { kind = Array a; _ }, Number f ->
      let i = Float.to_int f in
      if i >= 0 && i < a.length && Float.of_int i = f then Array.unsafe_get a.elements i else item_simple t o k
  | _ -> item_simple t o k

and put_item_opti (t : t) (o : value) (k : value) (v : value) : unit =
  match (o, k) with
  | Object { kind = Array a; _ }, Number f ->
      let i = Float.to_int f in
      if i >= 0 && i < a.length && Float.of_int i = f then a.elements.(i) <- flat v else put_item_simple t o k v
  | _ -> put_item_simple t o k v

and item (t : t) (o : value) (k : value) : value = if !Mini_opti.enabled then item_opti t o k else item_simple t o k
and put_item (t : t) (o : value) (k : value) (v : value) : unit = if !Mini_opti.enabled then put_item_opti t o k v else put_item_simple t o k v

(* a handler's trap, if it has that one *)
and trap (t : t) (handler : obj) (name : string) : value option =
  match Js_props.get (protos t) (Object handler) name with Object { kind = Closure _ | Host_function _; _ } as f -> Some f | _ -> None

(* k in o: its own or its prototypes'; a proxy's has(target, key) *)
and has_property (t : t) (o : value) (k : string) : bool =
  match o with
  | Object { kind = Proxy (tg, h); _ } -> (
      match trap t h "has" with Some f -> truthy (call_value t f ~this:(Object h) [ Object tg; String k ]) | None -> has_property t (Object tg) k)
  | Object o -> has t o k
  | _ -> false

(* the object of the nearest with (o) { } around [s] that has [x], if
 * no frame nearer declares x *)
and with_subject (t : t) (s : scope) (x : string) : value option =
  if Js_scope.own s x <> None then None
  else
    match (s.subject, s.parent) with
    | Some o, _ when has_property t o x -> Some o
    | _, Some p when p.in_with -> with_subject t p x
    | _ -> None

(* o.k = v: the property set, or its setter called (an object's own, or
 * its prototypes': looked for only where there can be one) *)
and put (t : t) (target : value) (k : string) (v : value) : unit =
  match target with
  | Object { kind = Proxy (tg, h); _ } -> (
      match trap t h "set" with Some f -> ignore (call_value t f ~this:(Object h) [ Object tg; String k; v; target ]) | None -> put t (Object tg) k v)
  | Object { kind = Plain | Closure _; _ } -> (
      match Js_props.get (protos t) target k with
      | Object { kind = Accessor (_, setter); _ } -> if setter <> Undefined then ignore (call_value t setter ~this:target [ v ])
      | _ -> Js_props.set target k v)
  (* the browser's own object (an element): a setter of that name on
   * its prototypes first -- the class a page gave a custom element
   * defines its properties so (Polymer: el.data = x is a call, which
   * draws the element again), and those the browser has are there as
   * setters that ask the object itself (data/prelude/web/) *)
  | Object { kind = Host_object _; proto = Some p; _ } when k <> "__proto__" -> (
      (* the page's prototypes only, down to the browser's own
       * (Js_props.dom_mark): what is there asks the object anyway *)
      let rec setter (o : obj) : value option =
        if get_own o Js_props.dom_mark <> None then None
        else
          match get_own o k with
          | Some (Object { kind = Accessor (_, s); _ }) -> Some s
          | Some _ -> None
          | None -> Option.bind o.proto setter
      in
      match setter p with Some s when s <> Undefined -> ignore (call_value t s ~this:target [ v ]) | _ -> Js_props.set target k v)
  | _ -> Js_props.set target k v

(* a pattern's names bound to the parts of a value, each by [bind]: a
 * name to the value; { } to its properties, by key, and what is left;
 * [ ] to its items, in order, and those left. A part that is
 * undefined takes its default *)
and destructure (t : t) (s : scope) (this : value) (pt : A.pattern) (v : value) (bind : string -> value -> unit) : unit =
  let or_default (v : value) (default : A.expr option) = match (v, default) with Undefined, Some d -> eval_expr t s this d | v, _ -> v in
  match pt with
  | Bind x -> bind x v
  | Object_pattern (parts, rest) ->
      (match v with Undefined | Null -> throw "TypeError" (Printf.sprintf "Cannot destructure '%s' as it is %s." (display v) (to_string v)) | _ -> ());
      let taken =
        List.map
          (fun ((k : A.key), part, default) ->
            let k = match k with Key k -> k | Computed e -> key_of (eval_expr t s this e) in
            destructure t s this part (or_default (get t v k) default) bind;
            k)
          parts
      in
      Option.iter
        (fun r ->
          let o = new_object () in
          (match v with Object src -> List.iter (fun k -> if not (List.mem k taken) then set_own o k (get t v k)) (keys src) | _ -> ());
          destructure t s this r (Object o) bind)
        rest
  | Array_pattern (parts, rest) ->
      let rec go parts items =
        match parts with
        | [] -> Option.iter (fun r -> destructure t s this r (Object (new_array items)) bind) rest
        | part :: more ->
            let v, left = match items with v :: left -> (v, left) | [] -> (Undefined, []) in
            Option.iter (fun (pt, default) -> destructure t s this pt (or_default v default) bind) part;
            go more left
      in
      go parts (items_of t v)

and closure (s : scope) (this : value) (f : A.func) : value =
  let c = { func = f; scope = s; this = (if f.arrow then Some this else None) } in
  let proto = if f.async then match lookup s "%async" with Some { value = Object p; _ } -> Some p | _ -> None else None in
  Object { (new_object ()) with kind = Closure c; proto }

and assign (t : t) (s : scope) (this : value) (target : A.expr) (v : value) : unit =
  match target with
  | Name x when s.in_with && with_subject t s x <> None -> put t (Option.get (with_subject t s x)) x v
  | Local (x, _) when s.in_with -> assign t s this (Name x) v
  | (Name x | Local (x, _)) as target -> (
      match (match target with Local (_, p) -> find s x p | _ -> lookup s x) with
      | Some { constant = true; _ } -> throw "TypeError" "Assignment to constant variable."
      | Some b -> b.value <- v
      (* a name nobody declared, assigned to: a global made, as scripts
       * not in strict mode have always relied on (Wikipedia's "RLQ = ...").
       * Before: ReferenceError, strict mode's answer *)
      | None -> declare t.globals x ~constant:false v)
  | Member (o, k) -> put t (eval_expr t s this o) k v
  | Index (o, k) ->
      let o = eval_expr t s this o in
      put_item t o (eval_expr t s this k) v
  (* [a, b] = v, ({ a, b: o.x } = v): the literal read as a pattern, each
   * part assigned to; "= d" after a part, its default *)
  | Array es ->
      let part (e : A.expr) (v : value) =
        match e with
        | Assign ("=", target, d) -> assign t s this target (if v = Undefined then eval_expr t s this d else v)
        | e -> assign t s this e v
      in
      let rec go es items =
        match (es, items) with
        | [], _ -> ()
        | [ A.Spread rest ], items -> assign t s this rest (Object (new_array items))
        | e :: more, v :: left -> part e v; go more left
        | e :: more, [] -> part e Undefined; go more []
      in
      go es (items_of t v)
  | Object props ->
      let taken = ref [] in
      List.iter
        (fun (pr : A.property) ->
          match pr with
          | Prop (k, target) -> (
              let k = match k with Key k -> k | Computed e -> key_of (eval_expr t s this e) in
              taken := k :: !taken;
              match (target, get t v k) with
              | Assign ("=", target, d), Undefined -> assign t s this target (eval_expr t s this d)
              | Assign ("=", target, _), pv | target, pv -> assign t s this target pv)
          (* ({ a, ...rest } = v): the keys not taken, in an object of their own *)
          | Spread_prop target ->
              let rest = new_object () in
              (match v with Object src -> List.iter (fun k -> if not (List.mem k !taken) then set_own rest k (get t v k)) (keys src) | _ -> ());
              assign t s this target (Object rest)
          | _ -> throw "SyntaxError" "Invalid assignment target")
        props
  | _ -> throw "SyntaxError" "Invalid assignment target"

and call_value (t : t) (fn : value) ~(this : value) (args : value list) : value =
  match fn with
  (* OCaml's functions are given Strings, never ropes *)
  | Object { kind = Host_function (_, (f : this:value -> value list -> value)); _ } ->
      let rope = function Rope _ -> true | _ -> false in
      f ~this:(flat this) (if List.exists rope args then List.map flat args else args)
  (* a proxy of a function: its handler's apply(target, this, arguments) *)
  | Object { kind = Proxy (tg, h); _ } -> (
      match trap t h "apply" with Some f -> call_value t f ~this:(Object h) [ Object tg; this; Object (new_array args) ] | None -> call_value t (Object tg) ~this args)
  | Object { kind = Closure c; _ } ->
      if t.depth >= max_depth then (
        (* JS_STACK=1: which function, to find the one that calls itself *)
        if !Js_value.stack_words <> None then !Js_value.say (Printf.sprintf "the stack is full in %s, line %d" ((match c.func.name with Some v_ -> v_ | None -> "(a function with no name)")) t.line);
        if !Js_value.stack_words <> None then unwinding := 40;
        throw "RangeError" "Maximum call stack size exceeded");
      (* __trace(n), called by a script (a console's line, a replay's
       * expression): the next n calls said, each with where its function
       * is written -- what a handler does when it does nothing *)
      if !tracing > 0 then (
        decr tracing;
        !Js_value.say (Printf.sprintf "call: %s%s, line %d%s" (String.make (min 40 t.depth) ' ') ((match c.func.name with Some v_ -> v_ | None -> "(no name)"))
            (match c.func.body with st :: _ -> st.line | [] -> 0)
            (match args with [] -> "" | a :: _ -> " (" ^ (let d = display a in if String.length d > 60 then String.sub d 0 60 ^ "..." else d) ^ (if List.length args > 1 then ", ..." else "") ^ ")")));
      t.depth <- t.depth + 1;
      if !watched <> None then watch_check ("entering " ^ (match c.func.name with Some v_ -> v_ | None -> "(no name)") ^ " of " ^ Filename.basename (module_url c.scope) ^ Printf.sprintf ", line %d" t.line);
      (* "use strict": its own, or that of the code it is written in (a
       * module and a class are strict always) *)
      let strict = c.scope.strict || match c.func.body with { stmt = Expr (String "use strict"); _ } :: _ -> true | _ -> false in
      let frame = Js_frame.make ~params:(bind_params t) c fn this args ~strict in
      let this =
        match (c.this, this) with
        | Some captured, _ -> captured
        (* a function called with no object, in code that is not
         * strict: its this is the global object -- 1995's rule, which
         * old libraries count on: (function () { this.x = 1 })() *)
        | None, (Undefined | Null) when not strict -> (
            match find t.globals "globalThis" t.global_this with Some b -> b.value | None -> this)
        | None, this -> this
      in
      let line = t.line in
      (* the caller's line back when the call returns; not when it
       * throws, so that the error keeps the line it was thrown on *)
      let body () =
        match c.func.frame with
        (* opti: its body compiled (Js_compile), the first time it is called *)
        | Some { code = A.Code (Compiled run); _ } -> run frame this
        | Some ({ code = A.No_code; _ } as l) when !Mini_opti.compiled && !compiler <> None ->
            let run = (Option.get !compiler) t c.func in
            l.code <- A.Code (Compiled run);
            run frame this
        | _ -> ( match exec_block_at ~top:true t frame this c.func.body with Return v -> v | _ -> Undefined)
      in
      (* an async function: its body a coroutine, run to its first
       * await; the call gives its promise *)
      (match if c.func.generator then generator t body else if c.func.async then Js_promise.async (Option.get t.promises) body else body () with
      | result ->
          t.depth <- t.depth - 1;
          if !watched <> None then watch_check ("leaving " ^ (match c.func.name with Some v_ -> v_ | None -> "(no name)") ^ " of " ^ Filename.basename (module_url c.scope));
          t.line <- line;
          result
      | exception e ->
          t.depth <- t.depth - 1;
          if !watched <> None then watch_check ("leaving " ^ (match c.func.name with Some v_ -> v_ | None -> "(no name)") ^ " of " ^ Filename.basename (module_url c.scope));
          (* JS_STACK=1: the calls an error leaves by, the innermost first (forty at most) *)
          if !unwinding > 0 then (
            decr unwinding;
            !Js_value.say
              (Printf.sprintf "  left %s%s%s" ((match c.func.name with Some v_ -> v_ | None -> "(no name)"))
                 (match c.func.body with st :: _ -> Printf.sprintf ", written at line %d" st.line | [] -> "")
                 (* of which module, and its parameters: what to grep for *)
                 (match module_url c.scope with "" -> "" | u -> " of " ^ Filename.basename u)
               (* and what each was given, cut short: which call it was *)
               ^ Printf.sprintf " (%s)"
                   (String.concat ", "
                      (List.mapi
                         (fun i (p, _) ->
                           let given = match List.nth_opt args i with Some v -> (let d = display v in if String.length d > 40 then String.sub d 0 40 ^ "..." else d) | None -> "nothing" in
                           (match p with A.Bind x -> x | _ -> "{..}") ^ " = " ^ given)
                         c.func.params))
               (* and how its text starts: what to find it by in a minified file *)
               ^ match c.func.text with Some (text, from, upto) -> "\n    " ^ String.sub text from (min 300 (upto - from)) | None -> ""));
          raise e)
  | _ -> throw "TypeError" (display fn ^ " is not a function")

(* the parameters bound in a call's frame to what it was given, each
 * by its name: a pattern's parts, a default, and those left *)
and bind_params (t : t) (frame : scope) (this : value) (ps : (A.pattern * A.expr option) list) (rest : A.pattern option) (args : value list) : unit =
  let bind x v = declare frame x ~constant:false v in
  match ps with
  | [] -> Option.iter (fun r -> destructure t frame this r (Object (new_array args)) bind) rest
  | (pt, default) :: more ->
      let v, left = match args with v :: left -> (v, left) | [] -> (Undefined, []) in
      (* a default is read in the call's frame: it sees the parameters before it *)
      let v = match (v, default) with Undefined, Some d -> eval_expr t frame this d | v, _ -> v in
      destructure t frame this pt v bind;
      bind_params t frame this more rest left

(*****************************************************************************)
(* Statements *)
(*****************************************************************************)

(* a block's statements in [s]: its function declarations first *)
and declare_functions ~(nested : bool) (s : scope) (this : value) (body : A.stmt list) : unit =
  List.iter
    (fun (st : A.stmt) ->
      match st.stmt with
      | Function_decl f | Export (Export_decl { stmt = Function_decl f; _ } | Export_default_decl { stmt = Function_decl f; _ }) -> (
          let name = Option.get f.name and v = closure s this f in
          declare s name ~constant:false v;
          (* in a block: the function's var of that name is given it too
           * (Js_frame.hoisted made the var; Annex B.3.3) -- unless what
           * is found there holds something else (a parameter) *)
          if nested then
            match Option.bind s.parent (fun p -> lookup p name) with
            | Some b when (not b.constant) && (match b.value with Undefined | Object { kind = Closure _; _ } -> true | _ -> false) -> b.value <- v
            | _ -> ())
      | _ -> ())
    body

and exec_block (t : t) (s : scope) (this : value) (body : A.stmt list) : outcome = exec_block_at ~top:false t s this body

and exec_block_at ~(top : bool) (t : t) (s : scope) (this : value) (body : A.stmt list) : outcome =
  declare_functions ~nested:(not top) s this body;
  let rec go (body : A.stmt list) =
    match body with
    | [] -> Normal
    | st :: rest -> ( match exec t s this st with Normal -> go rest | leave -> leave)
  in
  go body

(* a loop's body ran: whether the loop goes on (None), or how it ends *)
and after (labels : string list) (o : outcome) : outcome option =
  match o with
  | Normal | Continue None -> None
  | Continue (Some l) when List.mem l labels -> None
  | Break None -> Some Normal
  | leave -> Some leave

(* a branch's or a loop's body, in a scope of its own: a block makes its own *)
and inside (t : t) (s : scope) (this : value) (body : A.stmt) : outcome =
  match body.stmt with Block _ -> exec t s this body | _ -> exec t (new_scope s) this body

(* whether a block's statements declare a name of the block's own (let,
 * const, a class, a function): one that does not needs no scope *)
and declares (body : A.stmt list) : bool =
  List.exists (fun (st : A.stmt) -> match st.stmt with Let ((Let_kind | Const_kind), _) | Class_decl _ | Function_decl _ | Export _ -> true | _ -> false) body

(* [labels]: those of the statement, if it is a loop: "continue l" with
 * one of them goes on with it *)
and exec (t : t) (s : scope) (this : value) (st : A.stmt) : outcome = exec_labelled [] t s this st

(* [labels]: those of the statement, a loop's own *)
and exec_labelled (labels : string list) (t : t) (s : scope) (this : value) (st : A.stmt) : outcome =
  t.line <- st.line;
  tick t;
  let eval e = eval_expr t s this e in
  match st.stmt with
  | Expr e -> ignore (eval e); Normal
  | Let (Var_kind, decls) ->
      (* the function's binding, hoisted: set, not declared again *)
      let bind x v = match lookup s x with Some b -> b.value <- v | None -> declare s x ~constant:false v in
      List.iter
        (fun ((pt : A.pattern), init) ->
          match (pt, init) with
          (* var x; again: what it holds stays *)
          | Bind x, None -> if lookup s x = None then declare s x ~constant:false Undefined
          | pt, init -> destructure t s this pt (match init with Some e -> eval e | None -> Undefined) bind)
        decls;
      Normal
  | Let (kind, decls) ->
      List.iter
        (fun (pt, init) ->
          destructure t s this pt (match init with Some e -> eval e | None -> Undefined) (fun x v -> declare s x ~constant:(kind = Const_kind) v))
        decls;
      Normal
  (* opti: a var's plain names, each looked for where it was last
   * found (Js_quicken): the words of Let (Var_kind, ...) above *)
  | Var_set decls ->
      List.iter
        (fun (x, p, init) ->
          match init with
          | None -> if find s x p = None then declare s x ~constant:false Undefined
          | Some e -> (
              let v = eval e in
              match find s x p with Some b -> b.value <- v | None -> declare s x ~constant:false v))
        decls;
      Normal
  | Function_decl _ -> Normal (* defined by its block, first *)
  | Class_decl c ->
      declare s (Option.get c.class_name) ~constant:false (make_class t s this c);
      Normal
  | Return e -> Return (match e with Some e -> eval e | None -> Undefined)
  | If (c, a, b) -> (
      if truthy (eval c) then inside t s this a
      else match b with Some b -> inside t s this b | None -> Normal)
  | While (c, body) ->
      let rec loop () =
        if truthy (eval c) then match after labels (inside t s this body) with None -> loop () | Some o -> o else Normal
      in
      loop ()
  | With (o, body) ->
      let o = eval o in
      (match o with Undefined | Null -> throw "TypeError" (Printf.sprintf "Cannot convert %s to object" (to_string o)) | _ -> ());
      exec t (Js_scope.with_subject s o) this body
  | Do_while (body, c) ->
      let rec loop () =
        match after labels (inside t s this body) with None -> if truthy (eval c) then loop () else Normal | Some o -> o
      in
      loop ()
  | For (init, test, update, body) ->
      (* for (let i ...): a scope for i, and each iteration in a copy of
       * the last: its own i. A var's i is the function's *)
      let own = match init with Some { stmt = Let ((Let_kind | Const_kind), _); _ } -> true | _ -> false in
      let first = if own then new_scope s else s in
      Option.iter (fun i -> ignore (exec t first this i)) init;
      let rec loop (it : scope) =
        let ok = match test with Some c -> truthy (eval_expr t it this c) | None -> true in
        if not ok then Normal
        else
          match after labels (inside t it this body) with
          | Some o -> o
          | None ->
              let next = if own then Js_scope.copy it else it in
              Option.iter (fun u -> ignore (eval_expr t next this u)) update;
              loop next
      in
      loop first
  | For_of (kind, x, xs, body) | For_await (kind, x, xs, body) ->
      (* one item at a time: what is gone through may never end (a
       * generator), and a break tells it to stop *)
      let ended = ref Normal in
      let turn (v : value) : bool =
        let it = new_scope s in
        (* a var's, or a name's already there: set; else this turn's own *)
        let bind x v = match (kind, lookup s x) with A.Var_kind, Some b -> b.value <- v | _ -> declare it x ~constant:(kind = Const_kind) v in
        destructure t it this x v bind;
        match after labels (exec t it this body) with None -> true | Some o -> ended := o; false
      in
      let xs = eval xs in
      (match st.stmt with
      | For_await _ -> (
          let await v = Js_promise.await (Option.get t.promises) v in
          match (match xs with Object _ -> get t xs "@@asyncIterator" | _ -> Undefined) with
          (* its own way of giving items late: next() is a promise of { value, done } *)
          | Object { kind = Closure _ | Host_function _; _ } as make ->
              let it = call_value t make ~this:xs [] in
              let next = get t it "next" in
              let rec go () =
                let r = await (call_value t next ~this:it []) in
                if (not (truthy (get t r "done"))) && turn (get t r "value") then go ()
              in
              go ()
          | _ -> iterate t xs (fun v -> turn (await v)))
      | _ -> iterate t xs turn);
      !ended
  (* for (k in o): each key, a string; a var's, or a name's or a
   * property's, set before each turn *)
  | For_in (target, o, body) ->
      let rec loop keys =
        match keys with
        | [] -> Normal
        | k :: rest -> (
            let it = new_scope s in
            (match target with
            | Declared (Var_kind, x) -> ( match lookup s x with Some b -> b.value <- String k | None -> declare s x ~constant:false (String k))
            | Declared (kind, x) -> declare it x ~constant:(kind = Const_kind) (String k)
            | Target e -> assign t s this e (String k));
            match after labels (exec t it this body) with None -> loop rest | Some o -> o)
      in
      loop
        (match eval o with
        | Object { kind = Proxy (tg, h); _ } as o -> (
            match trap t h "ownKeys" with Some f -> List.map to_string (items_of t (call_value t f ~this:(Object h) [ Object tg ])) | None -> enumerable_keys o)
        | o -> enumerable_keys o)
  (* the first case that is === the value, and from there every
   * statement to a break, the next cases' too; no case: the default *)
  | Switch (e, cases) -> (
      let v = eval e in
      let sc = new_scope s in
      let rec from (cases : (A.expr option * A.stmt list) list) =
        match cases with
        | [] -> None
        | (Some test, _) :: rest when not (strict_equal v (eval_expr t sc this test)) -> from rest
        | (None, _) :: rest -> from rest
        | found -> Some found
      in
      let rec default (cases : (A.expr option * A.stmt list) list) =
        match cases with [] -> [] | (None, _) :: _ as found -> found | _ :: rest -> default rest
      in
      let run = match from cases with Some found -> found | None -> default cases in
      match exec_block t sc this (List.concat_map snd run) with Break None -> Normal | o -> o)
  | Labeled (l, body) -> ( match exec_labelled (l :: labels) t s this body with Break (Some l') when l' = l -> Normal | o -> o)
  | Break l -> Break l
  | Continue l -> Continue l
  | Throw e ->
      let v = eval e in
      Js_value.thrown (fun () -> display v);
      raise (Throw v)
  (* finally runs however the rest ended, and its own ending wins if
   * it is not the normal one *)
  | Try (body, handler, finally) ->
      let finish (ended : unit -> outcome) : outcome =
        match finally with
        | None -> ended ()
        | Some f -> (
            let run () = exec_block t (new_scope s) this f in
            match ended () with
            | o -> ( match run () with Normal -> o | leave -> leave)
            | exception e -> ( match run () with Normal -> raise e | leave -> leave))
      in
      finish (fun () ->
          match exec_block t (new_scope s) this body with
          | outcome -> outcome
          | exception Throw v when handler <> None ->
              let x, h = Option.get handler in
              let scope = new_scope s in
              Option.iter (fun x -> declare scope x ~constant:false v) x;
              exec_block t scope this h)
  | Block body -> exec_block t (if declares body then new_scope s else s) this body
  | Empty -> Normal
  (* a module's (Js_module): what is imported was bound before its
   * body ran; an export is its declaration, and the default a name
   * no script can write *)
  | Import _ -> Normal
  | Export (Export_decl st) -> exec t s this st
  | Export (Export_default e) ->
      declare s "*default*" ~constant:true (eval e);
      Normal
  | Export (Export_default_decl st) ->
      let o = exec t s this st in
      let name = match st.stmt with Function_decl f -> f.name | Class_decl c -> c.class_name | _ -> None in
      Option.iter (fun x -> Option.iter (fun (b : binding) -> declare s "*default*" ~constant:true b.value) (lookup s x)) name;
      o
  | Export (Export_names _ | Export_all _) -> Normal

(*****************************************************************************)
(* Entry points *)
(*****************************************************************************)

(* a program's statements, in the global scope *)
(* opti: a program's tree given its places, for an engine of the fast
 * kind (Js_quicken) *)
let quickened (s : scope) (program : A.program) : A.program = if Js_scope.slotted s then Js_quicken.program program else program

let run_in (t : t) (scope : scope) (this : value) (program : A.program) : value =
      let program = quickened t.globals program in
      (* the value of the last expression statement: a console's echo *)
      let last = ref Undefined in
      hoist scope program;
      List.iter
        (fun (st : A.stmt) -> match st.stmt with Function_decl f -> declare scope (Option.get f.name) ~constant:false (closure scope Undefined f) | _ -> ())
        program;
      List.iter
        (fun (st : A.stmt) ->
          match st.stmt with
          | Expr e ->
              t.line <- st.line;
              tick t;
              last := eval_expr t scope this e
          | _ -> (
              match exec t scope this st with
              | Normal -> ()
              | Return _ -> throw "SyntaxError" "Illegal return statement"
              | Break _ | Continue _ -> throw "SyntaxError" "Illegal break or continue statement"))
        program;
      !last

let run_in_run (t : t) (program : A.program) : value =
      (* a script's own this is the global object (a page's window): what
       * a library wrapped in (function (root) { ... })(this) is given *)
      run_in t t.globals (match Js_scope.own t.globals "globalThis" with Some b -> b.value | None -> Undefined) program

let () =
  direct_eval :=
    fun t s this text ->
      match Js_parse.parse text with
      (* in the caller's own scope: what it declares (a var, a function) is the caller's after it *)
      | Ok program -> run_in t s this program
      | Error e -> t.line <- e.line; throw "SyntaxError" e.message

let eval_in_run (t : t) (text : string) : value =
  match Js_parse.parse text with
  | Ok program -> run_in_run t program
  | Error e -> t.line <- e.line; throw "SyntaxError" e.message

let default_budget = 10_000_000

(* the library's part written in JavaScript (Js_prelude), parsed once *)
(* (ix: read at its first use and kept, by hand: mini-ml has no lazy) *)
let prelude_read : A.program option ref = ref None

let prelude () : A.program =
  match !prelude_read with
  | Some program -> program
  | None ->
      let program = match Js_parse.parse Js_prelude.text with Ok program -> program | Error e -> failwith (Printf.sprintf "data/prelude/library.js, line %d: %s" e.line e.message) in
      prelude_read := Some program;
      program

let create_with (log : string -> unit) (seed : int) (now : unit -> float) : t =
  let globals = Js_scope.global () in
  let t = { globals; protos = None; promises = None; line = 0; steps = default_budget; budget = default_budget; seconds = infinity; deadline = infinity; depth = 0; generators = []; importer = None; global_this = A.place () } in
  (* what a script's function gives back to OCaml is no rope either *)
  let call f ~this args = flat (call_value t f ~this args) in
  let define x v = declare globals x ~constant:false v in
  define "__trace" (host_function "__trace" (fun ~this:_ args -> tracing := (match args with Number n :: _ -> int_of_float n | _ -> 0); Undefined));
  define "__watch"
    (host_function "__watch" (fun ~this:_ args ->
         (match args with
         | [ Object { kind = Closure c; _ }; String name ] -> (
             match lookup c.scope name with Some b -> watched := Some (name, b, b.value) | None -> !Js_value.say ("watch: no " ^ name))
         | _ -> ());
         Undefined));
  (* new Function(params, body); an async one's constructor makes async ones *)
  let compile ~async params body = eval_in_run t (Printf.sprintf "(%sfunction anonymous(%s\n) {\n%s\n})" (if async then "async " else "") params body) in
  t.protos <- Some (Js_builtins.install ~call ~get:(fun v k -> get t v k) ~put:(fun v k x -> put t v k x) ~items:(fun v -> items_of t v) ~compile ~log ~seed ~now define);
  (* the prototype of async functions: Object.getPrototypeOf(async
   * function () {}).constructor is how a library gets to make one
   * from a text (Alpine) *)
  let async_proto = { (new_object ()) with proto = Some (protos t).functions } in
  set_own async_proto "constructor"
    (host_function "AsyncFunction" (fun ~this:_ args ->
         match List.rev (List.map to_string args) with [] -> compile ~async:true "" "" | body :: params -> compile ~async:true (String.concat "," (List.rev params)) body));
  declare globals "%async" ~constant:true (Object async_proto);
  (* eval(text): the text run as a program, its last expression's
   * value; of anything else, the thing itself. In the global scope
   * always: the names of the function calling it are not seen (a
   * "direct" eval's are, in JavaScript) *)
  define "eval" (host_function "eval" (fun ~this:_ args -> match args with String text :: _ -> eval_in_run t text | v :: _ -> v | [] -> Undefined));
  (* the helpers libraries look for: Symbol, Map, Object.defineProperty... *)
  Js_globals.install ~call ~lookup:(fun x -> Option.map (fun (b : binding) -> b.value) (Js_scope.own globals x))
    ~get:(fun v k -> get t v k) ~put:(fun v k x -> put t v k x) ~has:(has_property t) ~items:(fun v -> items_of t v) define;
  (* a rejection nobody handled, said as an error is *)
  let report v = log ("Uncaught (in promise) " ^ match v with Object o -> (match (get_own o "name", get_own o "message") with Some (String n), Some (String m) -> n ^ ": " ^ m | _ -> display v) | v -> display v) in
  t.promises <- Some (Js_promise.install ~call ~get:(get t) ~items:(fun v -> items_of t v) ~report define);
  (* the global object, by its standard name (a page's window is the browser's) *)
  define "globalThis" (host_object { class_name = "global"; get = (fun k -> match Js_scope.own globals k with Some b -> b.value | None -> Undefined); set = define; show = (fun () -> "[object global]") });
  (* the rest of the library, in the language itself *)
  (try ignore (run_in_run t (prelude ())) with Throw v -> log ("data/prelude/library.js: " ^ display v));
  (* what the language itself has does not show: for (k in
   * Array.prototype) goes through nothing, Object.keys(Math) is empty
   * (a method a page adds there shows, as it does in a browser: how a
   * site tells its page was tampered with -- Gmail's reports it) *)
  let hide_all (o : obj) = List.iter (hide o) (all_keys o) in
  List.iter
    (fun name ->
      match Js_scope.own globals name with
      | Some { value = Object o; _ } -> (
          hide_all o;
          match get_own o "prototype" with Some (Object p) -> hide_all p | _ -> ())
      | _ -> ())
    [ "Object"; "Array"; "String"; "Function"; "Number"; "Boolean"; "Symbol"; "BigInt"; "Promise"; "Map"; "Set"; "WeakMap"; "WeakSet"; "WeakRef"; "Date"; "RegExp"; "Error";
      "TypeError"; "RangeError"; "SyntaxError"; "ReferenceError"; "EvalError"; "URIError"; "AggregateError"; "ArrayBuffer"; "DataView"; "Int8Array"; "Uint8Array";
      "Uint8ClampedArray"; "Int16Array"; "Uint16Array"; "Int32Array"; "Uint32Array"; "Float32Array"; "Float64Array"; "Proxy"; "Reflect"; "Math"; "JSON"; "Intl"; "Iterator" ];
  (match t.protos with
  | Some ps -> List.iter hide_all [ ps.strings; ps.arrays; ps.objects; ps.functions; ps.regexps; ps.numbers ]
  | None -> ());
  Js_promise.drain (Option.get t.promises);
  t.steps <- t.budget;
  t

(* the engine running, for an object asked to be a primitive in the
 * middle of an operator (Js_value.own_primitive): its Symbol.toPrimitive,
 * else its valueOf and its toString, in the order the hint says, if
 * they are functions written in JavaScript and give a primitive *)
(* (a domain its own: each tab's engine runs on one) *)
let create () : t = create_with (fun _ -> ()) 1 (fun () -> 0.)

let running_here = Per_domain.make (fun () -> (ref None : t option ref))
let asked_here = Per_domain.make (fun () -> (ref [] : value list ref))

let () =
  Js_value.own_primitive :=
    fun v hint ->
      match !(running_here ()) with
      | None -> None
      | Some t -> (
          let ask (k : string) (args : value list) : value option =
            match get t v k with
            | Object { kind = Closure _; _ } as f -> ( match call_value t f ~this:v args with Object _ -> None | p -> Some p)
            (* a host's object with a toString of its own (a window's
             * selection, which is its text: "" + getSelection(); the
             * page's location, which is its address: location + "#top") *)
            | Object { kind = Host_function _; _ } as f when (match v with Object { kind = Host_object _; _ } -> not (List.memq v !(asked_here ())) | Object o -> get_own o k <> None | _ -> false) -> (
                (* (an element's toString is every object's, which asks
                 * the element for its string: once) *)
                asked_here () := v :: !(asked_here ());
                match Fun.protect ~finally:(fun () -> asked_here () := List.tl !(asked_here ())) (fun () -> call_value t f ~this:v args) with Object _ -> None | p -> Some p)
            | _ -> None
          in
          match ask "@@toPrimitive" [ String hint ] with
          | Some p -> Some p
          | None -> List.find_map (fun k -> ask k []) (if hint = "string" then [ "toString"; "valueOf" ] else [ "valueOf"; "toString" ]))

(* the error a console shows: an error object as "Name: message", any
 * other value thrown as "Uncaught " and it *)
let error_of (t : t) (v : value) : error =
  let message =
    match v with
    | Object o -> (
        match (get_own o "name", get_own o "message") with
        | Some (String n), Some (String m) -> n ^ ": " ^ m
        | _ -> "Uncaught " ^ display v)
    | v -> "Uncaught " ^ display v
  in
  { line = t.line; message }

(* a run or a call, its budget renewed, its throws caught; then the
 * jobs it left (the thens of the promises it settled) *)
let guarded (t : t) (f : unit -> value) : (value, error) result =
  t.steps <- t.budget;
  t.deadline <- !Js_value.wall_clock () +. t.seconds;
  t.depth <- 0;
  let before = !(running_here ()) in
  running_here () := Some t;
  Fun.protect ~finally:(fun () -> Js_promise.drain_each (fun () -> t.steps <- t.budget; t.deadline <- !Js_value.wall_clock () +. t.seconds) (Option.get t.promises); running_here () := before) @@ fun () ->
  match f () with
  | v -> Ok v
  | exception Throw v -> Error (error_of t v)
  | exception Stack_overflow -> Error { line = t.line; message = "RangeError: Maximum call stack size exceeded" }
  (* a mistake of the engine's own (an OCaml exception a
   * built-in let through): the script's error, never the browser's end *)
  | exception ((Invalid_argument _ | Failure _ | Not_found | Division_by_zero) as e) ->
      Error { line = t.line; message = "InternalError: " ^ Printexc.to_string e }

let run (t : t) (program : A.program) : (value, error) result = guarded t (fun () -> run_in_run t program)

(*****************************************************************************)
(* What modules ask (Js_module) *)
(*****************************************************************************)

let protect = guarded
let set_importer (t : t) (import : base:string -> string -> value) : unit = t.importer <- Some import
let names_of = Js_frame.pattern_names

(* a module's own scope, under the globals: what it declares is its
 * own, not the page's *)
let module_scope (t : t) ~(url : string) : scope =
  let s = Js_scope.strict t.globals in
  declare s "%module" ~constant:true (String url);
  s

(* a module's functions, there before it runs: what a module in a
 * circle with it can already take *)
let hoist_module (s : scope) (program : A.program) : unit =
  let program = quickened s program in
  hoist s program;
  declare_functions ~nested:false s Undefined program

(* a module's body, in its scope *)
let exec_module (t : t) (s : scope) (program : A.program) : unit =
  let program = quickened s program in
  hoist s program;
  match exec_block_at ~top:true t s Undefined program with
  | Normal -> ()
  | Return _ -> throw "SyntaxError" "Illegal return statement"
  | Break _ | Continue _ -> throw "SyntaxError" "Illegal break or continue statement"

let call_in_run (t : t) (f : value) ~(this : value) (args : value list) : value = flat (call_value t f ~this args)

(* opti: a text already read, where it was fetched (Js_module.ahead,
 * which sets this: a worker of the pool reads a script's megabytes
 * while the window's thread does something else). YouTube's 10 MB:
 * 3.2 s of parsing on the window's thread became 0.8 *)
let read_ahead : (string -> (A.program, Js_parse.error) result option) ref = ref (fun _ -> None)

let eval (t : t) (text : string) : (value, error) result =
  match (match !read_ahead text with Some r -> r | None -> Js_parse.parse text) with
  | Ok program -> run t program
  | Error e -> Error { line = e.line; message = "SyntaxError: " ^ e.message }

let call (t : t) (f : value) ~(this : value) (args : value list) : (value, error) result =
  guarded t (fun () -> call_value t f ~this args)

let promise (t : t) = Js_promise.make (Option.get t.promises)
let items = items_of

let global (t : t) (x : string) : value option = Option.map (fun (b : binding) -> b.value) (Js_scope.own t.globals x)
let define (t : t) (x : string) (v : value) : unit = declare t.globals x ~constant:false v
let set_budget (t : t) (steps : int) : unit = t.budget <- steps
let set_seconds (t : t) (seconds : float) : unit = t.seconds <- seconds
let running_for (t : t) : float = Float.max 0. (!Js_value.wall_clock () -. (t.deadline -. t.seconds))
