(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/library/Js_globals.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_globals.mli *)
open Js_value

let arg (args : value list) (i : int) : value = (match (List.nth_opt args i) with Some v_ -> v_ | None -> Undefined)
let fn = host_function
let array (vs : value list) : value = Object (new_array vs)
let is_symbol (k : string) : bool = String.length k >= 2 && k.[0] = '@' && k.[1] = '@'

(* the keys that are symbols a script made (Symbol("x"): "@@7:x"), not
 * the engine's own marks: what Object.assign copies besides the keys
 * that show, and what getOwnPropertySymbols lists *)
let own_symbols (v : value) : string list =
  match v with Object o -> List.filter (fun k -> String.length k > 2 && is_symbol k && k.[2] >= '0' && k.[2] <= '9') (keys (target o)) | _ -> []

(* an object's own keys that show: not a symbol's *)
let own_keys (v : value) : string list =
  match (match v with Object o -> Object (target o) | v -> v) with
  | Object ({ kind = Array a; _ } as o) -> List.init a.length string_of_int @ List.filter (fun k -> not (is_symbol k)) (keys o)
  | Object o -> List.filter (fun k -> not (is_symbol k)) (keys o)
  | String s -> List.init (Js_utf16.length s) string_of_int
  | _ -> []

(* all of them, those that do not show too *)
let own_names (v : value) : string list =
  match v with
  | Object ({ kind = Array a; _ } as o) when o.hidden <> [] -> List.init a.length string_of_int @ List.filter (fun k -> not (is_symbol k)) (all_keys o)
  | Object o when (target o).hidden <> [] -> List.filter (fun k -> not (is_symbol k)) (all_keys o)
  | v -> own_keys v

(* a key's value, read without calling a getter: an array's item, a
 * string's character, an object's own *)
let own (v : value) (k : string) : value =
  match ((match v with Object o -> Object (target o) | v -> v), int_of_string_opt k) with
  | Object { kind = Array a; _ }, Some i when i >= 0 && i < a.length -> a.elements.(i)
  | String s, Some i when i >= 0 && i < Js_utf16.length s -> String (Js_utf16.sub s i (i + 1))
  | Object o, _ -> (match (get_own o k) with Some v_ -> v_ | None -> Undefined)
  | _ -> Undefined

(* ===, but NaN is NaN: a Map's keys *)
let same_value (a : value) (b : value) : bool =
  match (a, b) with Number x, Number y when Float.is_nan x && Float.is_nan y -> true | _ -> strict_equal a b

(*****************************************************************************)
(* Object, Array, Number *)
(*****************************************************************************)

let object_statics : (string * value) list =
  (* a descriptor { value } or { get, set } made the property *)
  let define (o : obj) (k : string) (descriptor : value) : unit =
    let fresh = get_own o k = None in
    (* enumerable: as said; not said, a property made here does not
     * show (the standard's default: how a library hides what it adds) *)
    (match descriptor with
    | Object d -> ( match get_own d "enumerable" with Some v -> if truthy v then show o k else hide o k | None -> if fresh then hide o k)
    | _ -> ());
    let hidden = not (shows o k) in
    (match descriptor with
    | Object d -> (
        match (get_own d "get", get_own d "set") with
        (* what the descriptor does not say stays as it was: a
         * property made not enumerable keeps its value, an accessor
         * given a getter keeps its setter *)
        | None, None -> ( match (get_own d "value", get_own o k) with None, Some _ -> () | v, _ -> set_own o k ((match v with Some v_ -> v_ | None -> Undefined)))
        | g, s ->
            let g0, s0 = match get_own o k with Some (Object { kind = Accessor (g0, s0); _ }) -> (g0, s0) | _ -> (Undefined, Undefined) in
            set_own o k (Object { (new_object ()) with kind = Accessor ((match g with Some v_ -> v_ | None -> g0), (match s with Some v_ -> v_ | None -> s0)) }))
    | _ -> throw "TypeError" "Property description must be an object");
    (* (set_own shows a key it adds) *)
    if hidden then hide o k
  in
  let pairs v = List.map (fun k -> array [ String k; own v k ]) (own_keys v) in
  [ ("defineProperty",
     fn "defineProperty" (fun ~this:_ args ->
         match arg args 0 with
         | Object o as target -> define o (to_string (arg args 1)) (arg args 2); target
         (* which property, of what: the one clue to who called it *)
         | v -> throw "TypeError" (Printf.sprintf "Object.defineProperty called on non-object (%s of %s)" (to_string (arg args 1)) (display v))));
    ("defineProperties",
     fn "defineProperties" (fun ~this:_ args ->
         (match (arg args 0, arg args 1) with Object o, (Object ds as d) -> List.iter (fun k -> define o k (own d k)) (keys ds) | _ -> ());
         arg args 0));
    ("getOwnPropertyNames", fn "getOwnPropertyNames" (fun ~this:_ args -> array (List.map (fun k -> String k) (own_names (arg args 0)))));
    ("getOwnPropertySymbols", fn "getOwnPropertySymbols" (fun ~this:_ args -> array (List.map (fun k -> Symbol k) (own_symbols (arg args 0)))));
    ("getOwnPropertyDescriptor",
     fn "getOwnPropertyDescriptor" (fun ~this:_ args ->
         let k = to_string (arg args 1) in
         match arg args 0 with
         | Object o when get_own o k <> None || List.mem k (own_names (Object o)) -> (
             let d = new_object () in
             (match own (Object o) k with
             | Object { kind = Accessor (g, s); _ } -> set_own d "get" g; set_own d "set" s
             | v -> set_own d "value" v; set_own d "writable" (Bool true));
             set_own d "enumerable" (Bool (shows o k));
             set_own d "configurable" (Bool true);
             Object d)
         | _ -> Undefined));
    (* every own property's descriptor, by its key *)
    ("getOwnPropertyDescriptors",
     fn "getOwnPropertyDescriptors" (fun ~this:_ args ->
         let v = arg args 0 and all = new_object () in
         List.iter
           (fun k ->
             let d = new_object () in
             (match own v k with
             | Object { kind = Accessor (g, s); _ } -> set_own d "get" g; set_own d "set" s
             | x -> set_own d "value" x; set_own d "writable" (Bool true));
             set_own d "enumerable" (Bool (match v with Object o -> shows o k | _ -> true));
             set_own d "configurable" (Bool true);
             set_own all k (Object d))
           (own_names v);
         Object all));
    ("values", fn "values" (fun ~this:_ args -> let v = arg args 0 in array (List.map (own v) (own_keys v))));
    ("entries", fn "entries" (fun ~this:_ args -> array (pairs (arg args 0))));
    ("fromEntries",
     fn "fromEntries" (fun ~this:_ args ->
         let o = new_object () in
         (match arg args 0 with
         | Object ({ kind = Array _; _ } as a) -> List.iter (fun pair -> set_own o (to_string (own pair "0")) (own pair "1")) (array_items a)
         | _ -> ());
         Object o));
    ("setPrototypeOf",
     fn "setPrototypeOf" (fun ~this:_ args ->
         (match (arg args 0, arg args 1) with Object o, Object p -> o.proto <- Some p | Object o, Null -> o.proto <- None | _ -> ());
         arg args 0));
    (* nothing is frozen: the flags of a property are not kept *)
    ("freeze", fn "freeze" (fun ~this:_ args -> arg args 0));
    ("seal", fn "seal" (fun ~this:_ args -> arg args 0));
    ("preventExtensions", fn "preventExtensions" (fun ~this:_ args -> arg args 0));
    ("isFrozen", fn "isFrozen" (fun ~this:_ _ -> Bool false));
    ("isSealed", fn "isSealed" (fun ~this:_ _ -> Bool false));
    ("isExtensible", fn "isExtensible" (fun ~this:_ _ -> Bool true));
    ("is", fn "is" (fun ~this:_ args -> Bool (same_value (arg args 0) (arg args 1))));
    (* o.hasOwnProperty(k), called safely *)
    ("hasOwn", fn "hasOwn" (fun ~this:_ args -> Bool (List.mem (to_string (arg args 1)) (own_keys (arg args 0)) || match arg args 0 with Object o -> get_own o (to_string (arg args 1)) <> None | _ -> false)));
  ]

let number_statics : (string * value) list =
  let finite v = match v with Number f -> not (Float.is_nan f || Float.abs f = infinity) | _ -> false in
  [ ("isFinite", fn "isFinite" (fun ~this:_ args -> Bool (finite (arg args 0))));
    ("isNaN", fn "isNaN" (fun ~this:_ args -> Bool (match arg args 0 with Number f -> Float.is_nan f | _ -> false)));
    ("isInteger", fn "isInteger" (fun ~this:_ args -> Bool (match arg args 0 with Number f -> finite (Number f) && Float.is_integer f | _ -> false)));
    ("isSafeInteger", fn "isSafeInteger" (fun ~this:_ args -> Bool (match arg args 0 with Number f -> Float.is_integer f && Float.abs f <= 9007199254740991. | _ -> false)));
    ("MAX_SAFE_INTEGER", Number 9007199254740991.);
    ("MIN_SAFE_INTEGER", Number (-9007199254740991.));
    ("MAX_VALUE", Number max_float);
    ("MIN_VALUE", Number 5e-324);
    ("EPSILON", Number epsilon_float);
    ("POSITIVE_INFINITY", Number infinity);
    ("NEGATIVE_INFINITY", Number neg_infinity);
    ("NaN", Number nan) ]

(*****************************************************************************)
(* Symbol *)
(*****************************************************************************)

(* a symbol is a string no script would write: "@@" and its number or
 * its well-known name *)
let symbol () : value =
  let made = ref 0 and registry : (string, value) Hashtbl.t = Hashtbl.create 8 in
  let fresh description = incr made; Symbol (Printf.sprintf "@@%d:%s" !made description) in
  let description args = match arg args 0 with Undefined -> "" | v -> to_string v in
  let s = fn "Symbol" (fun ~this:_ args -> fresh (description args)) in
  (match s with
  | Object o ->
      List.iter (fun name -> set_own o name (Symbol ("@@" ^ name))) [ "iterator"; "asyncIterator"; "toStringTag"; "hasInstance"; "toPrimitive"; "species" ];
      (* Symbol.for: the same one for the same name *)
      set_own o "for"
        (fn "for" (fun ~this:_ args ->
             let key = description args in
             match Hashtbl.find_opt registry key with
             | Some v -> v
             | None -> let v = fresh key in Hashtbl.replace registry key v; v))
  | _ -> ());
  s

(*****************************************************************************)
(* Map, Set *)
(*****************************************************************************)

(* a collection's entries: found by their key, put, removed, and all of
 * them in the order they were put *)
type store = {
  find : value -> value option;
  put : value -> value -> unit;
  remove : value -> bool;
  clear : unit -> unit;
  all : unit -> (value * value) list;
  count : unit -> int;
}

(* the simple way: a list, the first put first, gone through for each key *)
let store_simple () : store =
  let entries : (value * value) list ref = ref [] in
  let has k = List.exists (fun (k', _) -> same_value k k') !entries in
  { find = (fun k -> Option.map snd (List.find_opt (fun (k', _) -> same_value k k') !entries));
    put = (fun k v -> if has k then entries := List.map (fun (k', v') -> if same_value k k' then (k', v) else (k', v')) !entries else entries := !entries @ [ (k, v) ]);
    remove = (fun k -> let there = has k in entries := List.filter (fun (k', _) -> not (same_value k k')) !entries; there);
    clear = (fun () -> entries := []);
    all = (fun () -> !entries);
    count = (fun () -> List.length !entries) }

(* opti: a hash table of the keys -- an object by its number, a string
 * by its text, a number by its value -- each entry with the turn it
 * was put at, by which they are sorted when all are asked. A framework
 * keeps what it knows of every object in WeakMaps of thousands of
 * entries: Discourse's front page, drawn by its scripts, 56 s with the
 * lists, 34 s so (2026-10-04) *)
let store_opti () : store =
  let table : (int, value * value ref * int) Hashtbl.t = Hashtbl.create 16 in
  let turn = ref 0 in
  let hash (k : value) : int =
    match k with
    | Object o -> o.id
    | String str -> Hashtbl.hash str
    | Number f -> if f = 0. then 0 else Hashtbl.hash f
    | Bool b -> if b then 1 else 2
    | _ -> 3
  in
  let cell k = List.find_opt (fun (k', _, _) -> same_value k k') (Hashtbl.find_all table (hash k)) in
  { find = (fun k -> match cell k with Some (_, v, _) -> Some !v | None -> None);
    put =
      (fun k v ->
        match cell k with
        | Some (_, r, _) -> r := v
        | None ->
            incr turn;
            Hashtbl.add table (hash k) (k, ref v, !turn));
    remove =
      (fun k ->
        let h = hash k in
        let there = Hashtbl.find_all table h in
        if List.exists (fun (k', _, _) -> same_value k k') there then (
          (* the bucket made again without it *)
          List.iter (fun _ -> Hashtbl.remove table h) there;
          List.iter (fun ((k', _, _) as e) -> if not (same_value k k') then Hashtbl.add table h e) (List.rev there);
          true)
        else false);
    clear = (fun () -> Hashtbl.reset table);
    all = (fun () -> Hashtbl.fold (fun _ (k, v, n) acc -> (n, (k, !v)) :: acc) table [] |> List.sort (fun (a, _) (b, _) -> compare a b) |> List.map snd);
    count = (fun () -> Hashtbl.length table) }

let store () : store = if !Mini_opti.enabled then store_opti () else store_simple ()

(* a Map's or a Set's constructor: each object made keeps its entries
 * (a Set's: its values, each its own key), the first put first. The
 * object has one thing of its own, hidden: what works on its entries,
 * a function given a method's name. The methods are the prototype's,
 * as the standard has them, each asking its this for that -- so
 * Map.prototype.set.call(m, k, v) is m.set(k, v), what a class made
 * of Map the old way calls (Closure's maps of a protocol buffer, in
 * Gmail), and a subclass's own set is not hidden by the object's.
 * opti: one property a map, not its twelve methods: 20,000 maps made
 * in 0.25 s, not 0.53 *)
let collection ~(call : value -> this:value -> value list -> value) ~(items : value -> value list) (name : string) ~(map : bool) : value =
  let proto = new_object () in
  let slot = "[[entries]]" in
  let make ~this args =
    let o = match this with Object o -> o | _ -> throw "TypeError" (Printf.sprintf "Constructor %s requires 'new'" name) in
    let st = store () in
    let put = st.put in
    let pair (k, v) = array [ k; v ] in
    let asked ~this:_ args =
      match (match args with String m :: rest -> (m, rest) | _ -> ("", [])) with
      | "has", args -> Bool (st.find (arg args 0) <> None)
      | "get", args -> (match (st.find (arg args 0)) with Some v_ -> v_ | None -> Undefined)
      | "set", args -> put (arg args 0) (arg args 1); this
      | "add", args -> put (arg args 0) (arg args 0); this
      | "delete", args -> Bool (st.remove (arg args 0))
      | "clear", _ -> st.clear (); Undefined
      | "forEach", args -> List.iter (fun (k, v) -> ignore (call (arg args 0) ~this:(arg args 1) [ v; k; this ])) (st.all ()); Undefined
      | "keys", _ -> Js_builtins.iterator (List.map fst (st.all ()))
      | "values", _ -> Js_builtins.iterator (List.map snd (st.all ()))
      | "size", _ -> Number (float_of_int (st.count ()))
      | "entries", _ -> Js_builtins.iterator (List.map pair (st.all ()))
      (* what a for-of and a spread go through: a Map's pairs, a Set's values *)
      | _ -> Js_builtins.iterator (if map then List.map pair (st.all ()) else List.map fst (st.all ()))
    in
    set_own o slot (fn name asked);
    hide o slot;
    (* new Map([[k, v], ...]), new Set([v, ...]) *)
    (match arg args 0 with
    | Undefined | Null -> ()
    | src -> List.iter (fun item -> if map then put (own item "0") (own item "1") else put item item) (items src));
    Undefined
  in
  let asked m : this:value -> value list -> value =
    let tag = String m in
    fun ~this args ->
    match this with
    | Object o -> (
        match get_own o slot with
        | Some (Object { kind = Host_function (_, (f : this:value -> value list -> value)); _ }) -> f ~this (tag :: args)
        | _ -> throw "TypeError" (Printf.sprintf "Method %s.prototype.%s called on incompatible receiver" name m))
    | _ -> throw "TypeError" (Printf.sprintf "Method %s.prototype.%s called on incompatible receiver" name m)
  in
  List.iter (fun m -> set_own proto m (fn m (asked m)); hide proto m)
    ([ "has"; "delete"; "clear"; "forEach"; "keys"; "values"; "entries"; "@@iterator" ] @ if map then [ "get"; "set" ] else [ "add" ]);
  set_own proto "size" (Object { (new_object ()) with kind = Accessor (fn "size" (fun ~this _ -> match this with Object o when get_own o slot <> None -> asked "size" ~this [] | _ -> Undefined), Undefined) });
  hide proto "size";
  let c = fn name make in
  (match c with Object o -> set_own o "prototype" (Object proto); set_own proto "constructor" c | _ -> ());
  c

(*****************************************************************************)
(* Proxy, Reflect *)
(*****************************************************************************)

(* new Proxy(target, handler): the traps are the interpreter's (Js_eval) *)
let proxy : value =
  fn "Proxy" (fun ~this:_ args ->
      match (arg args 0, arg args 1) with
      | Object tg, Object h -> Object { (new_object ()) with kind = Proxy (tg, h) }
      | _ -> throw "TypeError" "Cannot create proxy with a non-object as target or handler")

(* Reflect: what a trap does when it only wants the usual -- each
 * operation on an object as a function *)
let reflect ~(call : value -> this:value -> value list -> value) ~(lookup : string -> value option) ~(get : value -> string -> value)
    ~(put : value -> string -> value -> unit) ~(has : value -> string -> bool) : value =
  let o = new_object () in
  let def m f = set_own o m (fn m (fun ~this:_ args -> f args)) in
  let of_object m args = match lookup "Object" with Some (Object c) -> ( match get_own c m with Some f -> call f ~this:Undefined args | None -> Undefined) | _ -> Undefined in
  def "get" (fun args -> get (arg args 0) (to_string (arg args 1)));
  def "set" (fun args -> put (arg args 0) (to_string (arg args 1)) (arg args 2); Bool true);
  def "has" (fun args -> Bool (has (arg args 0) (to_string (arg args 1))));
  def "deleteProperty" (fun args ->
      (match arg args 0 with Object o -> let o = target o in o.props <- List.filter (fun (k, _) -> k <> to_string (arg args 1)) o.props | _ -> ());
      Bool true);
  (* an array's: its indices and "length" too *)
  def "ownKeys" (fun args ->
      let v = arg args 0 in
      array (List.map (fun k -> String k) (own_keys v @ match v with Object o when (match (target o).kind with Array _ -> true | _ -> false) -> [ "length" ] | _ -> [])));
  def "getPrototypeOf" (of_object "getPrototypeOf");
  def "defineProperty" (fun args -> ignore (of_object "defineProperty" args); Bool true);
  def "getOwnPropertyDescriptor" (of_object "getOwnPropertyDescriptor");
  def "apply" (fun args -> call (arg args 0) ~this:(arg args 1) (match arg args 2 with Object a -> array_items a | _ -> []));
  Object o

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

let install ~(call : value -> this:value -> value list -> value) ~(lookup : string -> value option) ~(get : value -> string -> value)
    ~(put : value -> string -> value -> unit) ~(has : value -> string -> bool) ~(items : value -> value list) (define : string -> value -> unit) : unit =
  let add name statics = match lookup name with Some (Object o) -> List.iter (fun (k, v) -> set_own o k v) statics | _ -> () in
  add "Object" object_statics;
  (* and what every object has from Object.prototype *)
  (match lookup "Object" with
  | Some (Object c) -> (
      match get_own c "prototype" with
      | Some (Object proto) ->
          let def m f = set_own proto m (fn m f) in
          def "propertyIsEnumerable" (fun ~this args -> Bool (List.mem (to_string (arg args 0)) (own_keys this)));
          (* a proxy's prototype is what its handler's getPrototypeOf
           * says, else its target's (a framework's tracked array: a
           * proxy that says it is of the framework's class) *)
          let plain = Option.get (get_own c "getPrototypeOf") in
          let rec prototype_of (v : value) : value =
            match v with
            | Object { kind = Proxy (tg, h); _ } -> (
                match get (Object h) "getPrototypeOf" with
                | Object _ as trap -> call trap ~this:(Object h) [ Object tg ]
                | _ -> prototype_of (Object tg))
            | v -> call plain ~this:Undefined [ v ]
          in
          set_own c "getPrototypeOf" (fn "getPrototypeOf" (fun ~this:_ args -> prototype_of (arg args 0)));
          (* Object.assign through the language's own reads and writes:
           * a source that is a proxy is asked its keys and each value
           * (a framework's arguments: a proxy whose get computes them),
           * a getter is called, a target's setter too *)
          (* Object.keys, values and entries of a proxy whose handler
           * says its keys (ownKeys) *)
          let plain_keys = Option.get (get_own c "keys") in
          let trapped (v : value) : value list option =
            match v with
            | Object { kind = Proxy (tg, h); _ } -> (
                match get (Object h) "ownKeys" with
                | Object _ as f -> Some (List.filter (fun k -> match k with String _ -> true | _ -> false) (match call f ~this:(Object h) [ Object tg ] with Object a -> array_items a | _ -> []))
                (* no such trap: the target's keys, the values still asked of the proxy *)
                | _ -> Some (List.map (fun k -> String k) (own_keys (Object tg))))
            | _ -> None
          in
          List.iter
            (fun (name, item) ->
              let plain = Option.get (get_own c name) in
              set_own c name
                (fn name (fun ~this args ->
                     match trapped (arg args 0) with
                     | Some ks -> array (List.map (fun k -> item (arg args 0) k) ks)
                     | None -> call plain ~this args)))
            [ ("keys", fun _ k -> k); ("values", fun v k -> get v (to_string k)); ("entries", fun v k -> array [ k; get v (to_string k) ]) ];
          ignore plain_keys;
          let keys_of = Option.get (get_own c "keys") in
          set_own c "assign"
            (fn "assign" (fun ~this:_ args ->
                 match args with
                 | (Object _ as target) :: sources ->
                     List.iter
                       (fun src ->
                         match src with
                         | Object _ | String _ ->
                             let ks = match call keys_of ~this:Undefined [ src ] with Object a -> array_items a | _ -> [] in
                             List.iter (fun k -> let k = to_string k in put target k (get src k)) ks;
                             (* and those whose key is a symbol (a mark put on an
                              * object and looked for with "in": Gmail's message
                              * view found none of its contexts, "Loading" for ever) *)
                             List.iter (fun k -> put target k (get src k)) (own_symbols src)
                         | _ -> ())
                       sources;
                     target
                 | v :: _ -> v
                 | [] -> Undefined));
          def "isPrototypeOf" (fun ~this args ->
              let rec up (o : obj) = match o.proto with Some p -> Object p == this || (match this with Object t -> t == p | _ -> false) || up p | None -> false in
              Bool
                (match arg args 0 with
                | Object { kind = Proxy _; _ } as v -> ( match prototype_of v with Object p -> (match this with Object t -> t == p | _ -> false) || up p | _ -> false)
                | Object o -> up o
                | _ -> false));
          def "valueOf" (fun ~this _ -> this);
          def "toLocaleString" (fun ~this _ -> to_primitive this)
      | _ -> ())
  | _ -> ());
  add "Number" number_statics;
  add "Array" [ ("of", fn "of" (fun ~this:_ args -> array args)) ];
  define "isFinite" (fn "isFinite" (fun ~this:_ args -> let f = to_number (arg args 0) in Bool (not (Float.is_nan f || Float.abs f = infinity))));
  (* typed arrays (ES2015) are arrays here: of zeros for a length, else
   * of the items given; no buffer under them, no wrapping of a number
   * too big for its type *)
  (* what they all inherit from, as in an engine: Object.getPrototypeOf(Int8Array),
   * whose prototype a library adds its methods to *)
  let typed = match fn "TypedArray" (fun ~this:_ _ -> throw "TypeError" "Abstract class TypedArray not directly constructable") with Object o -> o | _ -> assert false in
  set_own typed "prototype" (Object (new_object ()));
  List.iter
    (fun name ->
      (* its own prototype, an array's behind it: x instanceof Uint8Array,
       * and where the prelude puts buffer and byteLength *)
      let proto = new_object () in
      (match lookup "Array" with Some (Object a) -> ( match get_own a "prototype" with Some (Object p) -> proto.proto <- Some p | _ -> ()) | _ -> ());
      let of_kind (v : value) = (match v with Object a -> a.proto <- Some proto | _ -> ()); v in
      let c =
        fn name (fun ~this:_ args ->
            match arg args 0 with
            | Number n -> of_kind (array (List.init (max 0 (int_of_float n)) (fun _ -> Number 0.)))
            | Object ({ kind = Array _; _ } as a) -> of_kind (array (array_items a))
            (* over a buffer (the prelude's ArrayBuffer: its bytes an
             * array): the bytes themselves if all are asked for, a
             * view as it should be; else a copy of the part *)
            | Object b when get_own b "_bytes" <> None -> (
                match (get_own b "_bytes", arg args 1, arg args 2) with
                | Some (Object _ as bytes), (Undefined | Number 0.), Undefined -> of_kind bytes
                | Some (Object bytes), from, len ->
                    let all = Array.of_list (array_items bytes) in
                    let from = match from with Number f -> int_of_float f | _ -> 0 in
                    let len = match len with Number l -> int_of_float l | _ -> Array.length all - from in
                    of_kind (array (Array.to_list (Array.sub all (max 0 from) (max 0 (min len (Array.length all - from))))))
                | _ -> of_kind (array []))
            | _ -> of_kind (array []))
      in
      (match c with
      | Object c ->
          c.proto <- Some typed;
          set_own c "prototype" (Object proto);
          set_own proto "constructor" (Object c)
      | _ -> ());
      define name c)
    [ "Uint8Array"; "Int8Array"; "Uint8ClampedArray"; "Uint16Array"; "Int16Array"; "Uint32Array"; "Int32Array"; "Float32Array"; "Float64Array" ];
  define "Proxy" proxy;
  define "Reflect" (reflect ~call ~lookup ~get ~put ~has);
  define "Symbol" (symbol ());
  define "Map" (collection ~call ~items "Map" ~map:true);
  define "WeakMap" (collection ~call ~items "WeakMap" ~map:true);
  define "Set" (collection ~call ~items "Set" ~map:false);
  define "WeakSet" (collection ~call ~items "WeakSet" ~map:false)
