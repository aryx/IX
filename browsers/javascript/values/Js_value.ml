(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's languages/javascript/values/Js_value.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_value.mli *)

type value = Undefined | Null | Bool of bool | Number of float | String of string | Rope of rope | Symbol of string | Object of obj
and rope = { mutable pieces : pieces; size : int; units : int }
and pieces = Flat of string | Cat of rope * rope
and obj = { id : int; mutable props : (string * value ref) list; kind : kind; mutable proto : obj option; mutable lookup : lookup option; mutable hidden : string list; (* its properties by their key, when they are many (Js_value's find) *)
}

(* an object's properties in a table, good while its list is the one
 * the table was made from (==): what writes the list itself -- a
 * delete -- makes it stale with no word said *)
and lookup = { table : (string, value ref) Hashtbl.t; mutable of_props : (string * value ref) list }

and kind =
  | Plain
  | Array of items
  | Closure of closure
  | Host_function of string * (this:value -> value list -> value)
  | Host_object of host
  | Regexp of Js_regexp.t
  | Accessor of value * value
  | Proxy of obj * obj

and host = { class_name : string; get : string -> value; set : string -> value -> unit; show : unit -> string }

and items = { mutable elements : value array; mutable length : int; mutable holes : int }
and closure = { func : Js_ast.func; scope : scope; this : value option }
and scope = { vars : vars; parent : scope option; subject : value option; in_with : bool; strict : bool }

(* a scope's names: a table of them, the simple way; or, opti, an array
 * of bindings in the order they were declared (Js_scope) *)
and vars = Table of (string, binding) Hashtbl.t | Slots of slots
and slots = { mutable names : string array; mutable cells : binding array; mutable used : int; mutable index : (string, int) Hashtbl.t option; mutable fixed : int }
and binding = { mutable value : value; constant : bool }

exception Throw of value

exception Compiled of (scope -> value -> value)

(*****************************************************************************)
(* Objects *)
(*****************************************************************************)

let counter = ref 0

let make (kind : kind) : obj =
  incr counter;
  { id = !counter; props = []; kind; proto = None; lookup = None; hidden = [] }

let new_object () : obj = make Plain

(*****************************************************************************)
(* Ropes *)
(*****************************************************************************)

(* a rope's text: its pieces put end to end, once (then it is that
 * text). By a list of what is still to be written, not by calling
 * itself: a string grown a character at a time is a rope as deep as
 * it is long *)
let flatten (r : rope) : string =
  match r.pieces with
  | Flat s -> s
  | Cat _ ->
      let b = Bytes.create r.size in
      let rec go (at : int) (todo : rope list) =
        match todo with
        | [] -> ()
        | { pieces = Flat s; _ } :: rest ->
            Bytes.blit_string s 0 b at (String.length s);
            go (at + String.length s) rest
        | { pieces = Cat (l, r); _ } :: rest -> go at (l :: r :: rest)
      in
      go 0 [ r ];
      let s = Bytes.unsafe_to_string b in
      r.pieces <- Flat s;
      s

(* a value that is a rope, as the string it is: what everything but
 * [join] is given *)
let flat (v : value) : value = match v with Rope r -> String (flatten r) | v -> v

(* under this, two strings joined are a string *)
let rope_from = 1024

(* opti: two texts joined. Simply a ^ b; but a long text made by adding
 * to it again and again is copied whole at each addition (a script's
 * 60 KB grown a character at a time: 100,000 copies, 1.5 GB, and the
 * collector after each), so a long one is a rope: the two pieces
 * kept, written out when the text is first read. 200,000 additions
 * of two characters: 34 s to 0.3. YouTube's search, its scripts in
 * all: 28 s to 18 (with the styles' memo: a heap of 3.8 GB to 1.7) *)
let join (a : value) (b : value) : value =
  let size = function String s -> String.length s | Rope r -> r.size | _ -> 0 in
  let n = size a + size b in
  let piece = function String s -> { pieces = Flat s; size = String.length s; units = Js_utf16.length s } | Rope r -> r | _ -> { pieces = Flat ""; size = 0; units = 0 } in
  if n < rope_from || not !Mini_opti.enabled then
    (* (two halves of a pair that meet are their character: Js_utf16) *)
    String (Js_utf16.seam (match flat a with String s -> s | _ -> "") (match flat b with String s -> s | _ -> ""))
  else if size a = 0 then b
  else if size b = 0 then a
  else
    let a = piece a and b = piece b in
    Rope { pieces = Cat (a, b); size = n; units = a.units + b.units }

let new_array (vs : value list) : obj =
  (* an item is no rope: what is kept is a String *)
  let elements = Array.of_list (if List.exists (function Rope _ -> true | _ -> false) vs then List.map flat vs else vs) in
  make (Array { elements; length = Array.length elements; holes = 0 })

let host_function (name : string) (f : this:value -> value list -> value) : value = Object (make (Host_function (name, f)))
let host_object (h : host) : value = Object (make (Host_object h))
(* a proxy's own properties, keys and items are its target's:
 * what reads an object as it is (JSON, the console, Object.keys) sees
 * through a proxy, without its traps *)
let rec target (o : obj) : obj = match o.kind with Proxy (t, _) -> target t | _ -> o

(* List.assoc_opt, the keys compared as strings (it compares them as
 * any two values: a third of a program's time was there) *)
let rec property (k : string) (props : (string * value ref) list) : value ref option =
  match props with [] -> None | (k', r) :: rest -> if String.equal k k' then Some r else property k rest

(* opti: an object of many properties has a table of them (V8's
 * "dictionary mode", here beside the list, which stays the truth): made
 * the first time a search goes past [many] of them. A prototype has
 * dozens of methods, and each call of one was a walk of the list --
 * 43% of a program that calls methods, by callgrind (5.0 G instructions
 * to 3.5 G on a loop of method calls) *)
let many = 8

let indexed (o : obj) : unit =
  if !Mini_opti.enabled then (
    let table = Hashtbl.create 32 in
    List.iter (fun (k, r) -> Hashtbl.replace table k r) (List.rev o.props);
    o.lookup <- Some { table; of_props = o.props })

let find (o : obj) (k : string) : value ref option =
  match o.lookup with
  | Some ix when ix.of_props == o.props -> Hashtbl.find_opt ix.table k
  | _ ->
      let rec scan (props : (string * value ref) list) (n : int) =
        match props with
        | [] -> if n > many then indexed o; None
        | (k', r) :: rest -> if String.equal k k' then (if n > many then indexed o; Some r) else scan rest (n + 1)
      in
      scan o.props 0

let get_own (o : obj) (k : string) : value option = match find (target o) k with Some r -> Some !r | None -> None

let set_own (o : obj) (k : string) (v : value) : unit =
  let o = target o and v = flat v in
  match find o k with
  | Some r -> r := v
  | None -> (
      let before = o.props and r = ref v in
      o.props <- (k, r) :: before;
      (* a key set anew shows, whatever one of its name was before *)
      if o.hidden <> [] then o.hidden <- List.filter (fun h -> h <> k) o.hidden;
      (* the table follows a property added *)
      match o.lookup with
      | Some ix when ix.of_props == before ->
          Hashtbl.replace ix.table k r;
          ix.of_props <- o.props
      | _ -> ())

(* an object's own keys, in the order they were set: all of them, and
 * those that show (the enumerable ones) *)
let all_keys (o : obj) : string list = List.rev_map fst (target o).props

let keys (o : obj) : string list =
  let o = target o in
  let all = List.rev_map fst o.props in
  if o.hidden = [] then all else List.filter (fun k -> not (List.mem k o.hidden)) all

let hide (o : obj) (k : string) : unit = let o = target o in if not (List.mem k o.hidden) then o.hidden <- k :: o.hidden
let show (o : obj) (k : string) : unit = let o = target o in if o.hidden <> [] then o.hidden <- List.filter (fun h -> h <> k) o.hidden
let shows (o : obj) (k : string) : bool = not (List.mem k (target o).hidden)
let array_items (o : obj) : value list = match (target o).kind with Array a -> Array.to_list (Array.sub a.elements 0 a.length) | _ -> []

let error (name : string) (message : string) : value =
  let o = new_object () in
  set_own o "name" (String name);
  set_own o "message" (String message);
  (* where it was thrown is not kept: a text all the same, which a
   * library cuts (e.stack.trim()) *)
  set_own o "stack" (String (name ^ ": " ^ message ^ "\n    at <anonymous>"));
  (* none of the three shows: JSON.stringify(new Error("x")) is {} *)
  o.hidden <- [ "name"; "message"; "stack" ];
  hide o "stack";
  Object o

(* how many more calls to say, as an error leaves them: forty, from an
 * error whose message has JS_STACK's words in it (JS_STACK="reading
 * 'call'": where, in a bundle of megabytes, an undefined was read) *)
let unwinding = ref 0

let contains (s : string) (sub : string) : bool =
  let n = String.length sub in
  let rec at i = i + n <= String.length s && (String.sub s i n = sub || at (i + 1)) in
  at 0

(* JS_THROWS=n: the first n values thrown, by the engine or by a
 * script's throw, said as they are -- a framework catches its
 * components' errors and reports its own, later and elsewhere *)
(* ix: the debugging switches are values a host sets, where they were
 * the environment's JS_THROWS, JS_THROWS_NOT and JS_STACK; and what
 * they say goes to [say], which a host with the standard error gives
 * (nothing by default): the engine reaches no system by itself. The
 * clock is the host's too. *)
let say : (string -> unit) ref = ref (fun _ -> ())
let wall_clock : (unit -> float) ref = ref (fun () -> 0.)
let stack_words : string option ref = ref None
let throws_left = ref 0

(* JS_THROWS_NOT=words: but those that have these words (a script that
 * throws the same thing a thousand times on purpose) *)
let throws_not : string option ref = ref None

let thrown (what : unit -> string) : unit =
  if !throws_left > 0 && (match !throws_not with Some w -> not (contains (what ()) w) | None -> true) then (
    decr throws_left;
    !say ("throw: " ^ what ());
    if !unwinding = 0 then unwinding := 12)

let throw (name : string) (message : string) : 'a =
  thrown (fun () -> name ^ ": " ^ message);
  (match !stack_words with
  | Some words when words <> "" && words <> "1" && contains message words ->
      !say ("thrown: " ^ message);
      unwinding := 40
  | _ -> ());
  raise (Throw (error name message))

(*****************************************************************************)
(* Conversions *)
(*****************************************************************************)

let typeof (v : value) : string =
  match v with
  | Undefined -> "undefined"
  (* the mistake of 1995, kept since: pages relied on it *)
  | Null -> "object"
  | Bool _ -> "boolean"
  | Number _ -> "number"
  | String _ | Rope _ -> "string"
  | Symbol _ -> "symbol"
  | Object { kind = Closure _ | Host_function _; _ } -> "function"
  | Object { kind = Proxy ({ kind = Closure _ | Host_function _; _ }, _); _ } -> "function"
  | Object _ -> "object"

let truthy (v : value) : bool =
  match v with
  | Undefined | Null -> false
  | Bool b -> b
  | Number f -> not (f = 0. || Float.is_nan f)
  | String s -> s <> ""
  | Rope r -> r.size > 0
  | Symbol _ | Object _ -> true

(* -0 is printed 0, as JavaScript does *)
let number_to_string (f : float) : string = if f = 0. then "0" else Js_ast.number_to_string f

(* an object's own way to be a primitive -- its valueOf, its toString,
 * written in JavaScript -- asked of the engine that is running (Js_eval
 * sets this: only it can call a function); [hint] is "number", "string"
 * or "default". None: the object has none, or no engine runs *)
let own_primitive : (value -> string -> value option) ref = ref (fun _ _ -> None)

(* told of a property read on a host's object that it has not, nor its
 * prototypes: its class and the name (a browser's list of what a page
 * looked for and did not find); None, nobody is told *)
let missing : (string -> string -> unit) option ref = ref None

let rec to_string (v : value) : string =
  match v with
  | Undefined -> "undefined"
  | Null -> "null"
  | Bool b -> string_of_bool b
  | Number f -> number_to_string f
  | Rope r -> flatten r
  | String s -> s
  (* "@@7:saved" is Symbol(saved); "@@iterator", Symbol(Symbol.iterator) *)
  | Symbol k -> (
      match String.index_opt k ':' with
      | Some i -> Printf.sprintf "Symbol(%s)" (String.sub k (i + 1) (String.length k - i - 1))
      | None -> Printf.sprintf "Symbol(Symbol.%s)" (String.sub k 2 (String.length k - 2)))
  | Object _ -> to_string (to_primitive_as "string" v)

(* an object as a primitive: an array its items joined with commas
 * (undefined and null as ""), a function its source's stand-in, an
 * object what its own valueOf or toString says, else "[object Object]" *)
and to_primitive (v : value) : value = to_primitive_as "default" v

and to_primitive_as (hint : string) (v : value) : value =
  match v with
  | Object { kind = Proxy (t, _); _ } -> to_primitive (Object t)
  | Object ({ kind = Array _; _ } as o) ->
      String (String.concat "," (List.map (fun v -> match v with Undefined | Null -> "" | v -> to_string v) (array_items o)))
  (* a function as a string is its own text, as it was written: a page
   * reads it, compares it, even evaluates it again (an anti-abuse
   * script of Google's rebuilt a function from its text, and
   * "function () { ... }" is not one) *)
  | Object { kind = Closure { func = { text = Some (source, first, stop); _ }; _ }; _ } when stop <= String.length source && first < stop -> String (String.sub source first (stop - first))
  | Object { kind = Closure { func = { name; _ }; _ }; _ } ->
      String (Printf.sprintf "function %s() { [native code] }" ((match name with Some v_ -> v_ | None -> "")))
  | Object { kind = Host_function (name, _); _ } -> String (Printf.sprintf "function %s() { [native code] }" name)
  (* a host's object: what its own toString says (location's is the
   * page's address), else its class *)
  | Object { kind = Host_object h; _ } -> ( match !own_primitive v hint with Some p -> p | None -> String (Printf.sprintf "[object %s]" h.class_name))
  | Object { kind = Regexp re; _ } -> String (Printf.sprintf "/%s/%s" (Js_regexp.source re) (Js_regexp.flags re))
  (* an error, as Error.prototype.toString says it: "TypeError: ..."
   * (with no prototypes, told by its name and message) *)
  | Object ({ kind = Plain; _ } as o) -> (
      match !own_primitive v hint with
      | Some p -> p
      | None -> (
          match (get_own o "name", get_own o "message") with
          | Some (String name), Some (String message) -> String (name ^ ": " ^ message)
          | _ -> String "[object Object]"))
  | v -> v

let to_number (v : value) : float =
  (* a rope is a primitive already (to_primitive leaves it: + joins it); here its text is read *)
  match flat (to_primitive_as "number" v) with
  | Rope _ -> nan
  | Undefined -> nan
  | Null -> 0.
  | Bool b -> if b then 1. else 0.
  | Number f -> f
  | String s -> (
      let s = String.trim s in
      if s = "" then 0.
      else
        match s with
        | "Infinity" | "+Infinity" -> infinity
        | "-Infinity" -> neg_infinity
        | _ ->
            (* decimal digits, a point, an exponent, or 0x: nothing else
             * (OCaml's float_of_string also reads "nan", "1_000", "0b1") *)
            let ok = String.for_all (fun c -> (c >= '0' && c <= '9') || String.contains ".eE+-xXabcdefABCDEF" c) s in
            let hex = String.length s > 2 && (String.sub s 0 2 = "0x" || String.sub s 0 2 = "0X") in
            let decimal = not (String.exists (fun c -> String.contains "xXabcdfABCDF" c) s) in
            if ok && (hex || decimal) then (match (float_of_string_opt s) with Some v_ -> v_ | None -> nan) else nan)
  | Symbol _ | Object _ -> nan

let rec strict_equal (a : value) (b : value) : bool =
  match (a, b) with
  | Rope _, _ | _, Rope _ -> strict_equal (flat a) (flat b)
  | Undefined, Undefined | Null, Null -> true
  | Bool x, Bool y -> x = y
  | Number x, Number y -> x = y (* NaN is not equal to itself; +0 is -0 *)
  | String x, String y | Symbol x, Symbol y -> String.equal x y
  | Object x, Object y -> x == y
  | _ -> false

(*****************************************************************************)
(* Showing values *)
(*****************************************************************************)

(* a string between quotes, as a console shows one inside an array: its
 * quotes, backslashes and line ends escaped, its letters of any
 * alphabet as they are (OCaml's %S would write "café" as its bytes'
 * numbers) *)
let quoted (s : string) : string =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter
    (fun c ->
      match c with
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | '\t' -> Buffer.add_string b "\\t"
      | '\r' -> Buffer.add_string b "\\r"
      | c when c < ' ' -> Buffer.add_string b (Printf.sprintf "\\x%02x" (Char.code c))
      | c -> Buffer.add_char b c)
    s;
  Buffer.add_char b '"';
  Buffer.contents b

let display (v : value) : string =
  let rec go ~top (seen : obj list) (v : value) =
    match v with
    | String s -> if top then s else quoted s
    | Rope r -> go ~top seen (String (flatten r))
    | Object { kind = Proxy (t, _); _ } -> go ~top seen (Object t)
    | Object o when List.memq o seen -> "[Circular]"
    (* five deep and no further: an application's one object holds
     * all the others, each many times *)
    | Object { kind = Array _ | Plain; _ } when List.length seen >= 5 -> "..."
    | Object ({ kind = Array _; _ } as o) -> "[" ^ String.concat ", " (List.map (go ~top:false (o :: seen)) (array_items o)) ^ "]"
    | Object { kind = Accessor _; _ } -> "[Getter]"
    (* an error, whose fields do not show: as a console says it *)
    | Object ({ kind = Plain; hidden = _ :: _; _ } as o) when (match (get_own o "name", get_own o "message") with Some (String _), Some (String _) -> not (shows o "message") | _ -> false) ->
        to_string v
    | Object ({ kind = Plain; _ } as o) ->
        (* not a symbol's key ("@@...": a Map's iterator, a promise's state) *)
        let shown = List.filter (fun k -> not (String.length k >= 2 && String.sub k 0 2 = "@@")) (keys o) in
        "{" ^ String.concat ", " (List.map (fun k -> k ^ ": " ^ go ~top:false (o :: seen) (Option.get (get_own o k))) shown) ^ "}"
    | Object { kind = Closure { func = { name; _ }; _ }; _ } -> "function " ^ (match name with Some v_ -> v_ | None -> "(anonymous)")
    | Object { kind = Host_function (name, _); _ } -> "function " ^ name
    | Object { kind = Host_object h; _ } -> h.show ()
    | Object { kind = Regexp _; _ } -> to_string v
    | v -> to_string v
  in
  go ~top:true [] v

(* ix: at the top, where it was a let exception *)
exception Cycle

let to_json (v : value) : string option =
  let quote s =
    let b = Buffer.create (String.length s + 2) in
    Buffer.add_char b '"';
    String.iter
      (fun c ->
        match c with
        | '"' -> Buffer.add_string b "\\\""
        | '\\' -> Buffer.add_string b "\\\\"
        | '\n' -> Buffer.add_string b "\\n"
        | '\t' -> Buffer.add_string b "\\t"
        | '\r' -> Buffer.add_string b "\\r"
        | c when Char.code c < 0x20 -> Buffer.add_string b (Printf.sprintf "\\u%04x" (Char.code c))
        | c -> Buffer.add_char b c)
      s;
    Buffer.add_char b '"';
    Buffer.contents b
  in
  (* None: left out (undefined, a function) *)
  let rec go (seen : obj list) (v : value) : string option =
    match v with
    | Rope r -> go seen (String (flatten r))
    | Undefined -> None
    | Null -> Some "null"
    | Bool b -> Some (string_of_bool b)
    (* JSON has no NaN and no Infinity *)
    | Number f -> Some (if Float.is_finite f then number_to_string f else "null")
    | String s -> Some (quote s)
    | Object { kind = Proxy (t, _); _ } -> go seen (Object t)
    | Object o when List.memq o seen -> raise Cycle
    | Object ({ kind = Array _; _ } as o) ->
        Some ("[" ^ String.concat "," (List.map (fun v -> (match (go (o :: seen) v) with Some v_ -> v_ | None -> "null")) (array_items o)) ^ "]")
    | Object ({ kind = Plain; _ } as o) ->
        Some
          ("{"
          ^ String.concat ","
              (List.filter_map (fun k -> Option.map (fun s -> quote k ^ ":" ^ s) (go (o :: seen) (Option.get (get_own o k)))) (keys o))
          ^ "}")
    | Symbol _ | Object _ -> None
  in
  match go [] v with s -> s | exception Cycle -> None
