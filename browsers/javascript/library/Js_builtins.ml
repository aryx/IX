(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's languages/javascript/library/Js_builtins.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_builtins.mli *)
open Js_value

type protos = { strings : obj; arrays : obj; objects : obj; functions : obj; regexps : obj; numbers : obj }

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

(* what hasOwnProperty asks a host object: this, then the property's name *)
let own_query = "@@own:"

let arg (args : value list) (i : int) : value = (match (List.nth_opt args i) with Some v_ -> v_ | None -> Undefined)
let num (args : value list) (i : int) : float = to_number (arg args i)

(* an integer argument, [default] when absent *)
let int_arg (args : value list) (i : int) ~(default : int) : int =
  match arg args i with Undefined -> default | v -> let f = to_number v in if Float.is_nan f then 0 else int_of_float f

(* a start or end index: negative ones from the end, then clamped *)
let relative (i : int) (n : int) : int = if i < 0 then max 0 (n + i) else min i n

let obj_of (fields : (string * value) list) : value =
  let o = new_object () in
  List.iter (fun (k, v) -> set_own o k v) fields;
  Object o

let fn = host_function
let array (vs : value list) : value = Object (new_array vs)

(* an iterator over values known already: next() gives each as
 * { value, done: false }, then { done: true }; it is its own
 * [Symbol.iterator]() -- what an array's values(), a Map's keys() give *)
let iterator (vs : value list) : value =
  let left = ref vs in
  let o = new_object () in
  set_own o "next"
    (fn "next" (fun ~this:_ _ ->
         let r = new_object () in
         (match !left with
         | v :: rest -> left := rest; set_own r "value" v; set_own r "done" (Bool false)
         | [] -> set_own r "value" Undefined; set_own r "done" (Bool true));
         Object r));
  set_own o "@@iterator" (fn "[Symbol.iterator]" (fun ~this:_ _ -> Object o));
  Object o

(* a string's this, as the method sees it *)
let this_string (this : value) : string = to_string this

let this_array (name : string) (this : value) : obj * items =
  match this with
  | Object ({ kind = Array items; _ } as o) -> (o, items)
  | _ -> throw "TypeError" (Printf.sprintf "Array.prototype.%s called on something not an array" name)

let set_items (items : items) (vs : value list) : unit =
  items.elements <- Array.of_list vs;
  items.length <- List.length vs

(* the string's index of [needle] from [from], or -1 *)
let index_of (s : string) (needle : string) (from : int) : int =
  let n = String.length s and m = String.length needle in
  let rec go i = if i + m > n then -1 else if String.sub s i m = needle then i else go (i + 1) in
  go (max 0 from)

(*****************************************************************************)
(* Regular expressions *)
(*****************************************************************************)

(* a RegExp object, its prototype [proto] *)
let regexp_value (proto : obj) (re : Js_regexp.t) : value =
  let o = { (new_object ()) with kind = Regexp re } in
  o.proto <- Some proto;
  set_own o "lastIndex" (Number 0.);
  (* what it was made of: re.source, re.flags, re.global... *)
  let flags = Js_regexp.flags re in
  set_own o "source" (String (Js_regexp.source re));
  set_own o "flags" (String flags);
  List.iter (fun (name, c) -> set_own o name (Bool (String.contains flags c))) [ ("global", 'g'); ("ignoreCase", 'i'); ("multiline", 'm'); ("sticky", 'y'); ("unicode", 'u'); ("dotAll", 's') ];
  Object o

let compile (source : string) (flags : string) : Js_regexp.t =
  match Js_regexp.compile source flags with Ok re -> re | Error why -> throw "SyntaxError" ("Invalid regular expression: /" ^ source ^ "/: " ^ why)

(* a match as exec gives it: the matched text, each group's (undefined
 * if it took no part), its index and input *)
let match_array (re : Js_regexp.t option) (s : string) (spans : (int * int) option array) : value =
  let texts = Array.to_list (Array.map (function Some (a, b) -> String (String.sub s a (b - a)) | None -> Undefined) spans) in
  let a = new_array texts in
  (* the groups that have a name, (?<year>\d+): m.groups.year (ES2018) *)
  (match Option.map Js_regexp.names re with
  | Some ((_ :: _) as names) ->
      let groups = new_object () in
      List.iter (fun (name, i) -> set_own groups name (List.nth texts i)) names;
      set_own a "groups" (Object groups)
  | _ -> set_own a "groups" Undefined);
  set_own a "index" (Number (float_of_int (match spans.(0) with Some (i, _) -> Js_utf16.unit_of s i | None -> 0)));
  set_own a "input" (String s);
  Object a

(* every match of [re] in [s], left to right (an empty one moving on
 * by one) *)
let all_matches (re : Js_regexp.t) (s : string) : (int * int) option array list =
  let rec go from acc =
    if from > String.length s then List.rev acc
    else
      match Js_regexp.exec re s from with
      | Some spans -> (
          (* an empty match: on by one character, not into the middle of its bytes *)
          let rec next i = if i < String.length s && Char.code s.[i] land 0xC0 = 0x80 then next (i + 1) else i in
          match spans.(0) with Some (a, b) -> go (if b = a then next (b + 1) else b) (spans :: acc) | None -> List.rev acc)
      | None -> List.rev acc
  in
  go 0 []

(* a replacement's text: $& the match, $1..$9 its groups, $$ a dollar *)
let expand (re : Js_regexp.t option) (template : string) (s : string) (spans : (int * int) option array) : string =
  let b = Buffer.create (String.length template) in
  let n = String.length template in
  let group g = match if g < Array.length spans then spans.(g) else None with Some (x, y) -> String.sub s x (y - x) | None -> "" in
  let rec go i =
    if i < n then
      if template.[i] = '$' && i + 1 < n then (
        match template.[i + 1] with
        | '$' -> Buffer.add_char b '$'; go (i + 2)
        | '&' -> Buffer.add_string b (group 0); go (i + 2)
        | '1' .. '9' as c -> Buffer.add_string b (group (Char.code c - 48)); go (i + 2)
        (* $<name>: a named group's text *)
        | '<' when (match (re, String.index_from_opt template i '>') with Some _, Some _ -> true | _ -> false) ->
            let close = String.index_from template i '>' in
            (match List.assoc_opt (String.sub template (i + 2) (close - i - 2)) (Js_regexp.names (Option.get re)) with
            | Some g -> Buffer.add_string b (group g)
            | None -> ());
            go (close + 1)
        | _ -> Buffer.add_char b '$'; go (i + 1))
      else (Buffer.add_char b template.[i]; go (i + 1))
  in
  go 0;
  Buffer.contents b

(*****************************************************************************)
(* Strings *)
(*****************************************************************************)

let string_methods ~(call : value -> this:value -> value list -> value) ~(regexps : obj) : obj =
  let o = new_object () in
  (* a pattern: a RegExp's, or a string's (its characters as they are) *)
  let pattern (v : value) : Js_regexp.t =
    match v with
    | Object { kind = Regexp re; _ } -> re
    | v ->
        let s = to_string v in
        let b = Buffer.create (String.length s) in
        String.iter (fun c -> if String.contains "\\^$.|?*+()[]{}/" c then Buffer.add_char b '\\'; Buffer.add_char b c) s;
        compile (Buffer.contents b) ""
  in
  let def name f = set_own o name (fn name (fun ~this args -> f (this_string this) args)) in
  (* a string is counted in UTF-16's units, and kept in UTF-8's bytes
   * (Js_utf16): an index a script gives is made a byte's ([byte]), one
   * it is given a unit's ([units]); for ASCII both are the same *)
  let len = Js_utf16.length and cut = Js_utf16.sub and byte = Js_utf16.byte_of in
  let units s i = if i < 0 then i else Js_utf16.unit_of s i in
  def "toUpperCase" (fun s _ -> String (Js_utf16.recased ~upper:true s));
  def "toLowerCase" (fun s _ -> String (Js_utf16.recased ~upper:false s));
  def "slice" (fun s args ->
      let n = len s in
      let a = relative (int_arg args 0 ~default:0) n and b = relative (int_arg args 1 ~default:n) n in
      String (if b > a then cut s a b else ""));
  def "substring" (fun s args ->
      let n = len s in
      let clamp i = max 0 (min i n) in
      let a = clamp (int_arg args 0 ~default:0) and b = clamp (int_arg args 1 ~default:n) in
      let a, b = (min a b, max a b) in
      String (cut s a b));
  def "charAt" (fun s args ->
      let i = int_arg args 0 ~default:0 in
      String (if i >= 0 && i < len s then cut s i (i + 1) else ""));
  def "indexOf" (fun s args -> Number (float_of_int (units s (index_of s (to_string (arg args 0)) (byte s (int_arg args 1 ~default:0))))));
  (* each from a position, its second argument: includes(x, from),
   * startsWith(x, at), endsWith(x, upto) *)
  def "includes" (fun s args -> Bool (index_of s (to_string (arg args 0)) (byte s (int_arg args 1 ~default:0)) >= 0));
  def "startsWith" (fun s args ->
      let prefix = to_string (arg args 0) and at = byte s (max 0 (int_arg args 1 ~default:0)) in
      Bool (at + String.length prefix <= String.length s && String.sub s at (String.length prefix) = prefix));
  def "endsWith" (fun s args ->
      let suffix = to_string (arg args 0) and upto = byte s (max 0 (int_arg args 1 ~default:max_int)) in
      Bool (upto >= String.length suffix && String.sub s (upto - String.length suffix) (String.length suffix) = suffix));
  (* split(sep, limit): the first [limit] pieces *)
  let limited args (pieces : value list) : value = match arg args 1 with Undefined -> array pieces | n -> array (List.filteri (fun i _ -> i < int_of_float (to_number n)) pieces) in
  def "split" (fun s args ->
      match arg args 0 with
      | Undefined -> array [ String s ]
      | sep ->
          let sep = to_string sep in
          if sep = "" then limited args (List.init (len s) (fun i -> String (cut s i (i + 1))))
          else
            let rec go from acc =
              match index_of s sep from with
              | -1 -> List.rev (String (String.sub s from (String.length s - from)) :: acc)
              | i -> go (i + String.length sep) (String (String.sub s from (i - from)) :: acc)
            in
            limited args (go 0 []));
  def "trim" (fun s _ -> String (String.trim s));
  def "repeat" (fun s args ->
      let n = int_arg args 0 ~default:0 in
      if n < 0 then throw "RangeError" "Invalid count value" else String (String.concat "" (List.init n (fun _ -> s))));
  def "padStart" (fun s args ->
      let n = int_arg args 0 ~default:0 and pad = match arg args 1 with Undefined -> " " | v -> to_string v in
      let missing = n - len s in
      if missing <= 0 || pad = "" then String s
      else String (cut (String.concat "" (List.init missing (fun _ -> pad))) 0 missing ^ s));
  def "concat" (fun s args -> String (String.concat "" (s :: List.map to_string args)));
  def "lastIndexOf" (fun s args ->
      let needle = to_string (arg args 0) in
      let rec go i = if i < 0 then -1 else if i + String.length needle <= String.length s && String.sub s i (String.length needle) = needle then i else go (i - 1) in
      (* from its second argument backwards (s.lastIndexOf(p, 0) == 0: "starts with p", as Closure writes it) *)
      let from = match arg args 1 with Undefined -> max_int | v -> ( match to_number v with n when Float.is_nan n -> max_int | n -> byte s (max 0 (int_of_float n))) in
      Number (float_of_int (units s (go (min from (String.length s - String.length needle))))));
  def "charCodeAt" (fun s args ->
      let i = int_arg args 0 ~default:0 in
      Number (match Js_utf16.unit s i with -1 -> nan | u -> float_of_int u));
  def "substr" (fun s args ->
      let n = len s in
      let a = relative (int_arg args 0 ~default:0) n in
      let count = max 0 (min (int_arg args 1 ~default:(n - a)) (n - a)) in
      String (cut s a (a + count)));
  def "trimStart" (fun s _ -> let t = String.trim s in if t = "" then String "" else String (String.sub s (index_of s t 0) (String.length s - index_of s t 0)));
  def "toString" (fun s _ -> String s);
  (* with a regular expression, or a string as one *)
  (* for match and search a string is an expression's text ("a.c"
   * matches "abc"), where replace and split take it letter for letter *)
  let expression (v : value) : Js_regexp.t = match v with Object { kind = Regexp re; _ } -> re | Undefined -> compile "" "" | v -> compile (to_string v) "" in
  def "match" (fun s args ->
      let re = expression (arg args 0) in
      if Js_regexp.global re then
        match all_matches re s with
        | [] -> Null
        | ms -> array (List.map (fun spans -> match spans.(0) with Some (a, b) -> String (String.sub s a (b - a)) | None -> Undefined) ms)
      else match Js_regexp.exec re s 0 with Some spans -> match_array (Some re) s spans | None -> Null);
  def "search" (fun s args ->
      match Js_regexp.exec (expression (arg args 0)) s 0 with Some spans -> ( match spans.(0) with Some (a, _) -> Number (float_of_int (units s a)) | None -> Number (-1.)) | None -> Number (-1.));
  def "replace" (fun s args ->
      let re = pattern (arg args 0) in
      let ms = if Js_regexp.global re then all_matches re s else Option.to_list (Js_regexp.exec re s 0) in
      let b = Buffer.create (String.length s) in
      let last =
        List.fold_left
          (fun from spans ->
            match spans.(0) with
            | Some (a, e) ->
                Buffer.add_string b (String.sub s from (a - from));
                (match arg args 1 with
                | Object { kind = Closure _ | Host_function _; _ } as f ->
                    let groups = List.tl (Array.to_list (Array.map (function Some (x, y) -> String (String.sub s x (y - x)) | None -> Undefined) spans)) in
                    Buffer.add_string b (to_string (call f ~this:Undefined ((String (String.sub s a (e - a)) :: groups) @ [ Number (float_of_int (units s a)); String s ])))
                | v -> Buffer.add_string b (expand (Some re) (to_string v) s spans));
                e
            | None -> from)
          0 ms
      in
      Buffer.add_string b (String.sub s last (String.length s - last));
      String (Buffer.contents b));
  (* split by a regular expression *)
  let split = Option.get (get_own o "split") in
  set_own o "split"
    (fn "split" (fun ~this args ->
         match arg args 0 with
         | Object { kind = Regexp re; _ } ->
             let s = this_string this in
             let pieces, last =
               List.fold_left
                 (fun (acc, from) (spans : (int * int) option array) ->
                   match spans.(0) with
                   | Some (a, b) when b > a ->
                       (* the pattern's groups are pieces too, between the two they cut ("a.b" by /([.])/: a, ".", b) *)
                       let groups = List.init (Array.length spans - 1) (fun i -> match spans.(i + 1) with Some (x, y) -> String (String.sub s x (y - x)) | None -> Undefined) in
                       (List.rev_append groups (String (String.sub s from (a - from)) :: acc), b)
                   | _ -> (acc, from))
                 ([], 0) (all_matches re s)
             in
             limited args (List.rev (String (String.sub s last (String.length s - last)) :: pieces))
         | _ -> ( match split with Object { kind = Host_function (_, (f : this:value -> value list -> value)); _ } -> f ~this args | _ -> Undefined)));
  ignore regexps;
  o

(*****************************************************************************)
(* Arrays *)
(*****************************************************************************)

(* the items of something like an array -- a length and its
 * indices (a jQuery object, a proxy of an array, a string's letters) *)
let like_array ~(get : value -> string -> value) (v : value) : value list =
  match v with
  | Object { kind = Array _; _ } | String _ | Undefined | Null -> ( match v with Object a -> array_items a | String s -> List.init (Js_utf16.length s) (fun i -> String (Js_utf16.sub s i (i + 1))) | _ -> [])
  | v ->
      let n = match get v "length" with Number n when n > 0. && n < 1e7 -> int_of_float n | _ -> 0 in
      List.init n (fun i -> get v (string_of_int i))

(* the methods that change the array they are called on *)
let mutating = [ "push"; "pop"; "shift"; "unshift"; "splice"; "sort"; "reverse"; "fill" ]

let array_methods ~(call : value -> this:value -> value list -> value) ~(get : value -> string -> value) ~(put : value -> string -> value -> unit) : obj =
  let o = new_object () in
  (* a method of an array works on anything like one
   * ([].indexOf.call(jQueryObject, el), [].push.apply(it, found)): on
   * a copy of its items, written back to it if the method changes
   * them. Before: a TypeError, "called on something not an array" *)
  let def name f =
    set_own o name
      (fn name (fun ~this args ->
           match this with
           | Object ({ kind = Array items; _ } as arr) -> f arr items args
           | Undefined | Null -> throw "TypeError" (Printf.sprintf "Array.prototype.%s called on null or undefined" name)
           | this -> (
               let before = like_array ~get this in
               let copy = new_array before in
               let items = match copy.kind with Array items -> items | _ -> assert false in
               let result = f copy items args in
               (match this with
               | Object _ when List.mem name mutating ->
                   let after = array_items copy in
                   List.iteri (fun i v -> put this (string_of_int i) v) after;
                   (* the indices left over, gone *)
                   (match this with
                   | Object ({ kind = Plain | Closure _; _ } as o) ->
                       List.iteri (fun i _ -> if i >= List.length after then o.props <- List.remove_assoc (string_of_int i) o.props) before
                   | _ -> ());
                   put this "length" (Number (float_of_int (List.length after)))
               | _ -> ());
               (* a method that returns its array (sort, reverse) returns this one *)
               match result with Object r when r == copy -> this | r -> r)))
  in
  (* f(item, index, array) for each item, as the callbacks are called *)
  (* f called on each item: f(item, index, array), its this the second
   * argument of the method (xs.forEach(f, self)), undefined if none *)
  (* an item never given (new Array(3)'s, while still undefined) is
   * not gone through: [f] is not called for it *)
  let each (self : value) (arr : obj) (f : value) (k : value -> int -> unit) : unit =
    let holes = match arr.kind with Array a -> a.holes | _ -> 0 in
    List.iteri (fun i v -> k (if i < holes && v = Undefined then Undefined else call f ~this:self [ v; Number (float_of_int i); Object arr ]) i) (array_items arr)
  in
  (* its iterators: of its items, its indices, its pairs *)
  let indices arr = List.mapi (fun i _ -> Number (float_of_int i)) (array_items arr) in
  def "@@iterator" (fun arr _ _ -> iterator (array_items arr));
  def "values" (fun arr _ _ -> iterator (array_items arr));
  def "keys" (fun arr _ _ -> iterator (indices arr));
  def "entries" (fun arr _ _ -> iterator (List.map2 (fun i v -> array [ i; v ]) (indices arr) (array_items arr)));
  (* opti: push and pop at the array's end, in place. Simply:
   *   push: set_items items (array_items arr @ args)
   *   pop:  match List.rev (array_items arr) with last :: rest -> set_items items (List.rev rest); last
   * each the whole array made again: a list built by pushes was its
   * length squared (a Discourse topic drawn: 40 s to 12) *)
  def "push" (fun _ items args ->
      let k = List.length args in
      if items.length + k > Array.length items.elements then (
        let bigger = Array.make (max (items.length + k) (2 * Array.length items.elements)) Undefined in
        Array.blit items.elements 0 bigger 0 items.length;
        items.elements <- bigger);
      List.iteri (fun i v -> items.elements.(items.length + i) <- v) args;
      items.length <- items.length + k;
      Number (float_of_int items.length));
  def "pop" (fun _ items _ ->
      if items.length = 0 then Undefined
      else (
        let last = items.elements.(items.length - 1) in
        items.elements.(items.length - 1) <- Undefined;
        items.length <- items.length - 1;
        last));
  def "shift" (fun arr items _ -> match array_items arr with [] -> Undefined | first :: rest -> set_items items rest; first);
  def "unshift" (fun arr items args ->
      set_items items (args @ array_items arr);
      Number (float_of_int items.length));
  def "join" (fun arr _ args ->
      let sep = match arg args 0 with Undefined -> "," | v -> to_string v in
      String (String.concat sep (List.map (fun v -> match v with Undefined | Null -> "" | v -> to_string v) (array_items arr))));
  (* from a position, the second argument (a negative one: from the end) *)
  let find_index same arr v from =
    let items = array_items arr in
    let from = if from < 0 then max 0 (List.length items + from) else from in
    let rec go i l = match l with [] -> -1 | x :: r -> if i >= from && same x v then i else go (i + 1) r in
    go 0 items
  in
  def "indexOf" (fun arr _ args -> Number (float_of_int (find_index strict_equal arr (arg args 0) (int_arg args 1 ~default:0))));
  (* includes finds NaN, which is equal to nothing *)
  let same_zero a b = strict_equal a b || (match (a, b) with Number x, Number y -> Float.is_nan x && Float.is_nan y | _ -> false) in
  def "includes" (fun arr _ args -> Bool (find_index same_zero arr (arg args 0) (int_arg args 1 ~default:0) >= 0));
  def "lastIndexOf" (fun arr _ args ->
      let v = arg args 0 and items = array_items arr in
      let n = List.length items in
      let from = match arg args 1 with Undefined -> n - 1 | f -> ( match int_of_float (to_number f) with f when f < 0 -> n + f | f -> min f (n - 1)) in
      let rec go i l = match l with [] -> -1 | x :: r -> if i <= from && strict_equal x v then i else go (i - 1) r in
      Number (float_of_int (go (n - 1) (List.rev items))));
  (* splice(start, count, items...): the removed, the items put in their place *)
  def "splice" (fun arr items args ->
      let all = array_items arr in
      let n = items.length in
      let start = relative (int_arg args 0 ~default:0) n in
      let count = max 0 (min (int_arg args 1 ~default:(n - start)) (n - start)) in
      let inserted = match args with _ :: _ :: rest -> rest | _ -> [] in
      let before = List.filteri (fun i _ -> i < start) all and removed = List.filteri (fun i _ -> i >= start && i < start + count) all in
      let after = List.filteri (fun i _ -> i >= start + count) all in
      set_items items (before @ inserted @ after);
      array removed);
  def "slice" (fun arr items args ->
      let n = items.length in
      let a = relative (int_arg args 0 ~default:0) n and b = relative (int_arg args 1 ~default:n) n in
      array (List.filteri (fun i _ -> i >= a && i < b) (array_items arr)));
  def "concat" (fun arr items args ->
      let out = array (array_items arr @ List.concat_map (fun v -> match v with Object ({ kind = Array _; _ } as o) -> array_items o | v -> [ v ]) args) in
      (* what it starts with, holes and all *)
      (match out with Object { kind = Array o; _ } -> o.holes <- items.holes | _ -> ());
      out);
  def "reverse" (fun arr items _ -> set_items items (List.rev (array_items arr)); Object arr);
  def "sort" (fun arr items args ->
      let compare =
        match arg args 0 with
        | Undefined -> fun a b -> compare (to_string a) (to_string b)
        | f -> fun a b -> let r = to_number (call f ~this:Undefined [ a; b ]) in if r < 0. then -1 else if r > 0. then 1 else 0
      in
      (* stable, as JavaScript's has been since 2019; undefined last *)
      let defined, undefined = List.partition (fun v -> v <> Undefined) (array_items arr) in
      set_items items (List.stable_sort compare defined @ undefined);
      Object arr);
  def "forEach" (fun arr _ args -> each (arg args 1) arr (arg args 0) (fun _ _ -> ()); Undefined);
  def "map" (fun arr _ args ->
      let out = ref [] in
      each (arg args 1) arr (arg args 0) (fun r _ -> out := r :: !out);
      array (List.rev !out));
  def "filter" (fun arr _ args ->
      let items = Array.of_list (array_items arr) and out = ref [] in
      each (arg args 1) arr (arg args 0) (fun r i -> if truthy r then out := items.(i) :: !out);
      array (List.rev !out));
  def "reduce" (fun arr _ args ->
      let f = arg args 0 in
      let start, rest =
        match (args, array_items arr) with
        | [ _ ], [] -> throw "TypeError" "Reduce of empty array with no initial value"
        | [ _ ], x :: rest -> (x, List.mapi (fun i v -> (i + 1, v)) rest)
        | _, xs -> (arg args 1, List.mapi (fun i v -> (i, v)) xs)
      in
      List.fold_left (fun acc (i, v) -> call f ~this:Undefined [ acc; v; Number (float_of_int i); Object arr ]) start rest);
  let first (self : value) arr f =
    let rec go i l = match l with [] -> None | v :: r -> if truthy (call f ~this:self [ v; Number (float_of_int i); Object arr ]) then Some (i, v) else go (i + 1) r in
    go 0 (array_items arr)
  in
  def "find" (fun arr _ args -> match first (arg args 1) arr (arg args 0) with Some (_, v) -> v | None -> Undefined);
  def "findIndex" (fun arr _ args -> match first (arg args 1) arr (arg args 0) with Some (i, _) -> Number (float_of_int i) | None -> Number (-1.));
  def "some" (fun arr _ args -> Bool (first (arg args 1) arr (arg args 0) <> None));
  def "every" (fun arr _ args ->
      let f = arg args 0 in
      let self = arg args 1 in
      Bool (first Undefined arr (host_function "not" (fun ~this:_ a -> Bool (not (truthy (call f ~this:self a))))) = None));
  o

(*****************************************************************************)
(* The globals *)
(*****************************************************************************)

(* the longest prefix of [s] (after spaces) that reads as an integer in
 * [radix], else NaN: parseInt("42px") is 42 *)
let parse_int (s : string) (radix : int) : float =
  let s = String.trim s in
  let sign, s = if s <> "" && (s.[0] = '-' || s.[0] = '+') then ((if s.[0] = '-' then -1. else 1.), String.sub s 1 (String.length s - 1)) else (1., s) in
  let radix, s =
    if (radix = 16 || radix = 0) && String.length s > 1 && s.[0] = '0' && (s.[1] = 'x' || s.[1] = 'X') then (16, String.sub s 2 (String.length s - 2))
    else ((if radix = 0 then 10 else radix), s)
  in
  let digit c =
    let d = match c with '0' .. '9' -> Char.code c - 48 | 'a' .. 'z' -> Char.code c - 87 | 'A' .. 'Z' -> Char.code c - 55 | _ -> 99 in
    if d < radix then Some d else None
  in
  let rec go i acc = if i < String.length s then match digit s.[i] with Some d -> go (i + 1) ((acc *. float_of_int radix) +. float_of_int d) | None -> (i, acc) else (i, acc) in
  match go 0 0. with 0, _ -> nan | _, v -> sign *. v

(* the longest prefix that reads as a decimal number *)
let parse_float (s : string) : float =
  let s = String.trim s in
  let rec longest n = if n = 0 then nan else match float_of_string_opt (String.sub s 0 n) with Some f when not (String.contains (String.sub s 0 n) '_') -> f | _ -> longest (n - 1) in
  if String.starts_with ~prefix:"Infinity" s then infinity else longest (String.length s)

(*****************************************************************************)
(* Dates *)
(*****************************************************************************)

(* a day number since 1970-01-01 as its year, month (1-12), day: Howard
 * Hinnant's civil_from_days *)
let civil (days : int) : int * int * int =
  let z = days + 719468 in
  let era = (if z >= 0 then z else z - 146096) / 146097 in
  let doe = z - (era * 146097) in
  let yoe = (doe - (doe / 1460) + (doe / 36524) - (doe / 146096)) / 365 in
  let doy = doe - ((365 * yoe) + (yoe / 4) - (yoe / 100)) in
  let mp = ((5 * doy) + 2) / 153 in
  let d = doy - (((153 * mp) + 2) / 5) + 1 in
  let m = if mp < 10 then mp + 3 else mp - 9 in
  ((yoe + (era * 400)) + (if m <= 2 then 1 else 0), m, d)

(* a Date: its milliseconds since 1970 (UTC, the only zone here), its
 * getters *)
let date (ms : float) : value =
  let days = int_of_float (Float.floor (ms /. 86_400_000.)) in
  let in_day = ms -. (float_of_int days *. 86_400_000.) in
  let y, m, d = civil days in
  let field name v = (name, fn name (fun ~this:_ _ -> Number v)) in
  let hours = Float.floor (in_day /. 3_600_000.) and minutes = Float.floor (Float.rem in_day 3_600_000. /. 60_000.) in
  let seconds = Float.floor (Float.rem in_day 60_000. /. 1000.) in
  let iso = Printf.sprintf "%04d-%02d-%02dT%02.0f:%02.0f:%02.0f.%03.0fZ" y m d hours minutes seconds (Float.rem in_day 1000.) in
  let methods =
    [ field "getTime" ms; field "valueOf" ms; field "getFullYear" (float_of_int y); field "getMonth" (float_of_int (m - 1));
      field "getDate" (float_of_int d); field "getDay" (float_of_int (((days mod 7) + 11) mod 7)); field "getHours" hours;
      field "getMinutes" minutes; field "getSeconds" seconds; field "getMilliseconds" (Float.rem in_day 1000.);
      field "getTimezoneOffset" 0.;
      ("toISOString", fn "toISOString" (fun ~this:_ _ -> String iso)); ("toString", fn "toString" (fun ~this:_ _ -> String iso)) ]
    |> List.concat_map (fun (k, v) -> if String.starts_with ~prefix:"get" k then [ (k, v); ("getUTC" ^ String.sub k 3 (String.length k - 3), v) ] else [ (k, v) ])
  in
  host_object
    { class_name = "Date"; get = (fun k -> (match (List.assoc_opt k methods) with Some v_ -> v_ | None -> Undefined)); set = (fun _ _ -> ()); show = (fun () -> iso) }

(*****************************************************************************)
(* URIs *)
(*****************************************************************************)

(* encodeURIComponent: every byte but letters, digits and -_.!~*'() as
 * %XX; encodeURI keeps a URI's punctuation too *)
let percent_encode ~(keep : string) (s : string) : string =
  let b = Buffer.create (String.length s) in
  String.iter
    (fun c ->
      if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || String.contains keep c then Buffer.add_char b c
      else Buffer.add_string b (Printf.sprintf "%%%02X" (Char.code c)))
    s;
  Buffer.contents b

let percent_decode (s : string) : string =
  let b = Buffer.create (String.length s) in
  let n = String.length s in
  let rec go i =
    if i < n then
      if s.[i] = '%' && i + 2 < n + 0 && i + 2 <= n - 1 then
        match int_of_string_opt ("0x" ^ String.sub s (i + 1) 2) with Some c -> Buffer.add_char b (Char.chr c); go (i + 3) | None -> Buffer.add_char b '%'; go (i + 1)
      else (Buffer.add_char b s.[i]; go (i + 1))
  in
  go 0;
  Buffer.contents b

let install ~(call : value -> this:value -> value list -> value) ~(get : value -> string -> value) ~(put : value -> string -> value -> unit)
    ~(items : value -> value list) ~compile:(make_function : async:bool -> string -> string -> value) ~(log : string -> unit) ~(seed : int) ~(now : unit -> float)
    (define : string -> value -> unit) : protos =
  let shown args = String.concat " " (List.map display args) in
  define "console"
    (obj_of
       [ ("log", fn "log" (fun ~this:_ args -> log (shown args); Undefined));
         ("error", fn "error" (fun ~this:_ args -> log (shown args); Undefined));
         ("warn", fn "warn" (fun ~this:_ args -> log (shown args); Undefined)) ]);
  let seed = ref (Lehmer.scramble seed) in
  let math1 name f = (name, fn name (fun ~this:_ args -> Number (f (num args 0)))) in
  let fold name init pick = (name, fn name (fun ~this:_ args -> Number (List.fold_left (fun m v -> let x = to_number v in if Float.is_nan m || Float.is_nan x then nan else pick m x) init args))) in
  define "Math"
    (obj_of
       [ math1 "floor" Float.floor; math1 "ceil" Float.ceil;
         (* half up, not half to even: Math.round(-2.5) is -2 *)
         math1 "round" (fun x -> Float.floor (x +. 0.5));
         math1 "trunc" Float.trunc; math1 "abs" Float.abs; math1 "sqrt" Float.sqrt;
         math1 "sign" (fun x -> if Float.is_nan x then x else if x > 0. then 1. else if x < 0. then -1. else x);
         ("pow", fn "pow" (fun ~this:_ args -> Number (Float.pow (num args 0) (num args 1))));
         fold "min" infinity Float.min; fold "max" neg_infinity Float.max;
         ("random", fn "random" (fun ~this:_ _ -> seed := Lehmer.next !seed; Number (Lehmer.to_unit !seed)));
         math1 "sin" Float.sin; math1 "cos" Float.cos; math1 "tan" Float.tan; math1 "asin" asin; math1 "acos" acos;
         math1 "atan" Float.atan; math1 "exp" Float.exp; math1 "log" Float.log;
         ("atan2", fn "atan2" (fun ~this:_ args -> Number (Float.atan2 (num args 0) (num args 1))));
         ("PI", Number Float.pi); ("E", Number (Float.exp 1.)); ("LN2", Number (Float.log 2.)); ("LN10", Number (Float.log 10.));
         ("LOG2E", Number (1. /. Float.log 2.)); ("LOG10E", Number (1. /. Float.log 10.)); ("SQRT2", Number (Float.sqrt 2.));
         ("SQRT1_2", Number (Float.sqrt 0.5)) ]);
  (* the prototypes: an object's, a function's, a regular expression's,
   * a number's; a string's and an array's below *)
  let objects = new_object () and functions = new_object () and regexps = new_object () and numbers = new_object () in
  let method_ (o : obj) name f = set_own o name (fn name f) in
  (* a host object says which properties a script put on it (an
   * element's: kept by the browser, not in the object): asked by
   * [own_query] and the name *)
  method_ objects "hasOwnProperty" (fun ~this args ->
      let k = to_string (arg args 0) in
      match this with
      | Object ({ kind = Host_object h; _ } as o) -> Bool (get_own o k <> None || h.get (own_query ^ k) = Bool true)
      | Object o -> Bool (get_own o k <> None)
      | Undefined | Null -> throw "TypeError" "Cannot convert undefined or null to object"
      | _ -> Bool false);
  (* Object.prototype.toString.call(x): "[object Array]", how a script
   * asked what a value was before Array.isArray; an object's own
   * Symbol.toStringTag is its name. On an error and a host's object,
   * what they say of themselves *)
  method_ objects "toString" (fun ~this _ ->
      let tag name = String (Printf.sprintf "[object %s]" name) in
      match this with
      | Undefined -> tag "Undefined"
      | Null -> tag "Null"
      | Bool _ -> tag "Boolean"
      | Number _ -> tag "Number"
      | String _ -> tag "String"
      | Object { kind = Array _; _ } -> tag "Array"
      | Object { kind = Closure _ | Host_function _; _ } -> tag "Function"
      | Object { kind = Regexp _; _ } -> tag "RegExp"
      | Object ({ kind = Plain; _ } as o) -> (
          let rec own (o : obj) (k : string) = match get_own o k with Some v -> Some v | None -> Option.bind o.proto (fun p -> own p k) in
          match (own o "@@toStringTag", get_own o "name", get_own o "message") with
          | Some (String t), _, _ -> tag t
          | _, Some (String _), Some (String _) -> to_primitive this
          | _ -> tag "Object")
      | v -> to_primitive v);
  method_ functions "call" (fun ~this args -> match args with [] -> call this ~this:Undefined [] | self :: rest -> call this ~this:self rest);
  method_ functions "apply" (fun ~this args ->
      call this ~this:(arg args 0) (match arg args 1 with Object ({ kind = Array _; _ } as a) -> array_items a | _ -> []));
  method_ functions "bind" (fun ~this args ->
      let f = this and self = arg args 0 and bound = match args with _ :: rest -> rest | [] -> [] in
      (* new on a bound function makes one of the function it is of,
       * with the arguments bound (how a container of services builds a
       * class it was given: new (Function.prototype.bind.apply(C,
       * [null].concat(args)))). Its prototype is that function's, and
       * a new, empty object of that prototype for this is a new *)
      let proto = get f "prototype" in
      let made (this : value) = match (this, proto) with Object o, Object p -> o.props = [] && (match o.proto with Some q -> q == p | None -> false) | _ -> false in
      let b = fn "bound" (fun ~this more -> call f ~this:(if made this then this else self) (bound @ more)) in
      (match (b, proto) with Object bo, Object _ -> set_own bo "prototype" proto; hide bo "prototype" | _ -> ());
      b);
  let regexp_of this = match this with Object { kind = Regexp re; _ } -> re | _ -> throw "TypeError" "not a RegExp" in
  (* exec and test: from lastIndex, and moving it, when global -- or
   * sticky (y: a match at lastIndex itself, how a parser written with
   * regular expressions reads its text piece by piece; it was read as
   * 0 each time, and such a parser never moved) *)
  let exec this s =
    let re = regexp_of this in
    let o = match this with Object o -> o | _ -> assert false in
    let moves = Js_regexp.global re || Js_regexp.sticky re in
    (* lastIndex is a script's: in units (Js_utf16), the engine's in bytes *)
    let from = if moves then int_of_float (to_number ((match (get_own o "lastIndex") with Some v_ -> v_ | None -> (Number 0.)))) else 0 in
    match if from > Js_utf16.length s then None else Js_regexp.exec re s (Js_utf16.byte_of s from) with
    | Some spans ->
        (if moves then match spans.(0) with Some (_, e) -> set_own o "lastIndex" (Number (float_of_int (Js_utf16.unit_of s e))) | None -> ());
        Some spans
    | None ->
        if moves then set_own o "lastIndex" (Number 0.);
        None
  in
  method_ regexps "exec" (fun ~this args -> let s = to_string (arg args 0) in match exec this s with Some spans -> match_array (match this with Object { kind = Regexp re; _ } -> Some re | _ -> None) s spans | None -> Null);
  method_ regexps "test" (fun ~this args -> Bool (exec this (to_string (arg args 0)) <> None));
  method_ regexps "toString" (fun ~this _ -> to_primitive this);
  method_ numbers "toFixed" (fun ~this args -> String (Printf.sprintf "%.*f" (int_arg args 0 ~default:0) (to_number this)));
  method_ numbers "toString" (fun ~this _ -> String (to_string this));
  let strings = string_methods ~call ~regexps and arrays = array_methods ~call ~get ~put in
  (* a constructor with its prototype and its own functions *)
  let constructor name f (proto : obj) (statics : (string * value) list) =
    let c = fn name f in
    (match c with
    | Object o ->
        set_own o "prototype" (Object proto);
        set_own proto "constructor" c;
        List.iter (fun (k, v) -> set_own o k v) statics
    | _ -> ());
    define name c
  in
  (* new Number(5), new String("a"): an object that holds the value
   * (kept under a key no script writes; its prototype's valueOf gives
   * it back: data/prelude/library.js). Number(5) alone is the value *)
  let boxed (this : value) (v : value) : value = (match this with Object ({ kind = Plain; _ } as o) -> set_own o "@@primitive" v | _ -> ()); v in
  constructor "String" (fun ~this args -> boxed this (String (match args with [] -> "" | v :: _ -> to_string v))) strings
    [ ("fromCharCode", fn "fromCharCode" (fun ~this:_ args -> String (Js_utf16.of_units (List.map (fun v -> (match to_number v with n when Float.is_finite n -> int_of_float n | _ -> 0) land 0xFFFF) args)))) ];
  constructor "Number" (fun ~this args -> boxed this (Number (match args with [] -> 0. | v :: _ -> to_number v))) numbers [];
  (* new Function("a", "b", "return a + b"): its last argument
   * the body, those before its parameters; a function of the global
   * scope. Before: an EvalError *)
  constructor "Function"
    (fun ~this:_ args ->
      match List.rev (List.map to_string args) with
      | [] -> make_function ~async:false "" ""
      | body :: params -> make_function ~async:false (String.concat "," (List.rev params)) body)
    functions [];
  constructor "RegExp"
    (fun ~this:_ args ->
      match arg args 0 with
      | Object { kind = Regexp re; _ } -> regexp_value regexps re
      | v -> regexp_value regexps (compile (to_string v) (match arg args 1 with Undefined -> "" | f -> to_string f)))
    regexps [];
  constructor "Date"
    (fun ~this:_ args -> date (match args with [] -> now () | v :: _ -> to_number v))
    (new_object ())
    [ ("now", fn "now" (fun ~this:_ _ -> Number (now ()))) ];
  (* Error and its kinds: an error object, with new or without *)
  List.iter
    (fun name ->
      let proto = new_object () in
      set_own proto "name" (String name);
      constructor name (fun ~this:_ args -> error name (match arg args 0 with Undefined -> "" | v -> to_string v)) proto [])
    [ "Error"; "TypeError"; "RangeError"; "SyntaxError"; "ReferenceError" ];
  define "encodeURIComponent" (fn "encodeURIComponent" (fun ~this:_ args -> String (percent_encode ~keep:"-_.!~*'()" (to_string (arg args 0)))));
  define "encodeURI" (fn "encodeURI" (fun ~this:_ args -> String (percent_encode ~keep:"-_.!~*'();/?:@&=+$,#" (to_string (arg args 0)))));
  define "decodeURIComponent" (fn "decodeURIComponent" (fun ~this:_ args -> String (percent_decode (to_string (arg args 0)))));
  define "decodeURI" (fn "decodeURI" (fun ~this:_ args -> String (percent_decode (to_string (arg args 0)))));
  define "Boolean" (fn "Boolean" (fun ~this:_ args -> Bool (truthy (arg args 0))));
  define "parseInt" (fn "parseInt" (fun ~this:_ args -> Number (parse_int (to_string (arg args 0)) (int_arg args 1 ~default:0))));
  define "parseFloat" (fn "parseFloat" (fun ~this:_ args -> Number (parse_float (to_string (arg args 0)))));
  define "isNaN" (fn "isNaN" (fun ~this:_ args -> Bool (Float.is_nan (num args 0))));
  define "NaN" (Number nan);
  define "Infinity" (Number infinity);
  define "undefined" Undefined;
  define "JSON"
    (obj_of
       [ ("stringify",
          fn "stringify" (fun ~this:_ args ->
              match to_json (arg args 0) with
              | Some s -> String s
              | None -> if arg args 0 = Undefined then Undefined else throw "TypeError" "Converting circular structure to JSON"));
         (* a text read into values (Js_json) *)
         ("parse", fn "parse" (fun ~this:_ args -> Js_json.parse (to_string (arg args 0)))) ]);
  constructor "Object"
    (fun ~this:_ args -> match arg args 0 with (Object _ | Symbol _) as o -> o | _ -> Object (new_object ()))
    objects
    [ ("create",
       fn "create" (fun ~this:_ args ->
           let o = new_object () in
           (match arg args 0 with Object p -> o.proto <- Some p | _ -> ());
           Object o));
      (* the one it was given, else its kind's (Js_props.proto_of) *)
      ("getPrototypeOf",
       fn "getPrototypeOf" (fun ~this:_ args ->
           match arg args 0 with
           (* of nothing: an error, not nothing -- a loop that goes up a
            * chain of prototypes ends there (it went round for ever on null) *)
           | Undefined | Null -> throw "TypeError" "Cannot convert undefined or null to object"
           | Object { proto = Some p; _ } -> Object p
           | Object { kind = Array _; _ } -> Object arrays
           | Object { kind = Closure _ | Host_function _; _ } -> Object functions
           | Object { kind = Regexp _; _ } -> Object regexps
           | Object ({ kind = Plain; _ } as o) when o != objects -> Object objects
           | String _ -> Object strings
           | _ -> Null));
      ("assign",
       fn "assign" (fun ~this:_ args ->
           match args with
           | (Object target as t) :: sources ->
               (* a source's getter is called: its value is what is copied, not the accessor *)
               let read (o : obj) (k : string) = match Option.get (get_own o k) with Object { kind = Accessor (g, _); _ } -> ( match g with Undefined -> Undefined | g -> call g ~this:(Object o) []) | v -> v in
               List.iter (fun v -> match v with Object o -> List.iter (fun k -> set_own target k (read o k)) (keys o) | _ -> ()) sources;
               t
           | v :: _ -> v
           | [] -> Undefined));
      ("keys",
          fn "keys" (fun ~this:_ args ->
              match arg args 0 with
              | Object ({ kind = Array a; _ }) -> array (List.init a.length (fun i -> String (string_of_int i)))
              (* not a symbol's key ("@@...": Js_globals) *)
              | Object o -> array (List.filter_map (fun k -> if String.length k >= 2 && String.sub k 0 2 = "@@" then None else Some (String k)) (keys o))
              | _ -> array [])) ];
  constructor "Array"
    (fun ~this:_ args ->
      match args with
      | [ Number n ] ->
          (* new Array(3): three places, none given *)
          let a = array (List.init (int_of_float n) (fun _ -> Undefined)) in
          (match a with Object { kind = Array items; _ } -> items.holes <- items.length | _ -> ());
          a
      | _ -> array args)
    arrays
    [ ("isArray", fn "isArray" (fun ~this:_ args -> Bool (match arg args 0 with Object o -> (match (target o).kind with Array _ -> true | _ -> false) | _ -> false)));
      (* of what can be gone through (an array, a string, a Set),
       * else of what is like an array ({ length: 3 }); each item through
       * the function given, if one is *)
      ("from",
       fn "from" (fun ~this:_ args ->
           let src = arg args 0 in
           let vs = match src with Object { kind = Plain | Host_object _ | Closure _; _ } when get src "@@iterator" = Undefined -> like_array ~get src | Undefined | Null -> [] | _ -> items src in
           array (match arg args 1 with Undefined -> vs | f -> List.mapi (fun i v -> call f ~this:Undefined [ v; Number (float_of_int i) ]) vs))) ];
  { strings; arrays; objects; functions; regexps; numbers }
