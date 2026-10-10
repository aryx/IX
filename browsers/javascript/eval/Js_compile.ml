(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's languages/javascript/eval/Js_compile.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Js_compile.mli *)
open Js_value
module A = Js_ast
module E = Js_eval

(* an expression compiled: given a scope and a this, its value; a
 * statement: how it ended *)
type code = scope -> value -> value
type outcome = E.outcome = Normal | Return of value | Break of string option | Continue of string option
type run = scope -> value -> outcome

(*****************************************************************************)
(* Operators *)
(*****************************************************************************)

(* a 32-bit integer already (NaN is not) *)
let small (x : float) : bool = x >= -2147483648. && x <= 2147483647. && Float.of_int (Float.to_int x) = x

(* an operator found once, by its name: a function of two values, two
 * numbers first and anything else Js_operators'. None: one the
 * evaluator does itself (instanceof, in) *)
(* true and false made once: a comparison's answer allocates nothing *)
let yes = Bool true
and no = Bool false

let bool (b : bool) : value = if b then yes else no

let binary (op : string) : (value -> value -> value) option =
  let slow = Js_operators.arithmetic_simple op in
  let numbers (f : float -> float -> value) : (value -> value -> value) option =
    Some (fun a b -> match (a, b) with Number x, Number y -> f x y | _ -> slow a b)
  in
  let bits (f : int -> int -> int) : (value -> value -> value) option =
    Some (fun a b -> match (a, b) with Number x, Number y when small x && small y -> Number (Float.of_int (f (Float.to_int x) (Float.to_int y))) | _ -> slow a b)
  in
  match op with
  | "instanceof" | "in" -> None
  | "+" -> numbers (fun x y -> Number (x +. y))
  | "-" -> numbers (fun x y -> Number (x -. y))
  | "*" -> numbers (fun x y -> Number (x *. y))
  | "/" -> numbers (fun x y -> Number (x /. y))
  | "<" -> numbers (fun x y -> bool (x < y))
  | ">" -> numbers (fun x y -> bool (x > y))
  | "<=" -> numbers (fun x y -> bool (x <= y))
  | ">=" -> numbers (fun x y -> bool (x >= y))
  | "===" | "==" -> numbers (fun x y -> bool (x = y))
  | "!==" | "!=" -> numbers (fun x y -> bool (x <> y))
  | "|" -> bits ( lor )
  | "&" -> bits ( land )
  | "^" -> bits ( lxor )
  | ">>" -> bits (fun x y -> x asr (y land 31))
  | _ -> Some slow

(* opti: a method of a built-in prototype (an array's push, a string's
 * charCodeAt), found once at the place that calls it and not by going
 * through the prototype's forty names at each call: kept with the
 * prototype's list of properties it was found in, and good as long as
 * that list is the very one (==: a property added or deleted makes
 * another). None: not there, or a getter -- the evaluator's *)
let inherited (k : string) : obj -> value option =
  let seen : (string * value ref) list ref = ref [] and found : value ref option ref = ref None in
  fun (proto : obj) ->
    if proto.props != !seen then (
      seen := proto.props;
      found := Js_value.property k proto.props);
    match !found with Some { contents = Object { kind = Accessor _; _ } } | None -> None | Some cell -> Some !cell

let callable (fn : value) : bool = match fn with Object { kind = Closure _ | Host_function _ | Proxy _; _ } -> true | _ -> false
let spread (es : A.expr list) : bool = List.exists (fun (e : A.expr) -> match e with Spread _ -> true | _ -> false) es

(* each one's value, in order *)
let rec values (cs : code list) (s : scope) (this : value) : value list =
  match cs with [] -> [] | c :: rest -> let v = c s this in v :: values rest s this

(*****************************************************************************)
(* Expressions *)
(*****************************************************************************)

let rec expr (t : E.t) (e : A.expr) : code =
  (* what is not compiled: the evaluator's, on the tree *)
  let walk : code = fun s this -> E.eval_expr t s this e in
  match e with
  | Number f -> let v = Number f in fun _ _ -> v
  | String x -> let v = String x in fun _ _ -> v
  | Bool b -> let v = Bool b in fun _ _ -> v
  | Null -> fun _ _ -> Null
  | This -> fun _ this -> this
  (* a name: three in four are the function's own or the one around's
   * (a million reads a frame of the Playground's menu), read here by
   * the place's slot if the name there is the very one (==); the rest,
   * and a place not learned yet, by Js_scope.at *)
  | Local (x, p) ->
      let far (s : scope) (this : value) : value =
        if s.in_with then walk s this
        else
          let b = Js_scope.at s x p in
          if b == Js_scope.nothing then throw "ReferenceError" (x ^ " is not defined") else b.value
      in
      fun s this ->
        if s.in_with then far s this
        else if p.hops = 0 then
          match s.vars with
          | Slots sl when p.slot < sl.used && Array.unsafe_get sl.names p.slot == x -> (Array.unsafe_get sl.cells p.slot).value
          | _ -> far s this
        else if p.hops = 1 then
          match s.parent with
          | Some { vars = Slots sl; _ } when p.slot < sl.used && Array.unsafe_get sl.names p.slot == x -> (Array.unsafe_get sl.cells p.slot).value
          | _ -> far s this
        else far s this
  | Unary ("!", a) -> let a = expr t a in fun s this -> bool (not (truthy (a s this)))
  | Unary ("-", a) -> let a = expr t a in fun s this -> Number (-.to_number (a s this))
  | Unary ("void", a) -> let a = expr t a in fun s this -> ignore (a s this); Undefined
  | Unary ("typeof", a) when (match a with Name _ | Local _ -> false | _ -> true) -> let a = expr t a in fun s this -> String (typeof (a s this))
  (* typeof of a name: "undefined" if nobody declared it, not an error *)
  | Unary ("typeof", Local (x, p)) ->
      fun s this ->
        if s.in_with then walk s this
        else
          let b = Js_scope.at s x p in
          String (if b == Js_scope.nothing then "undefined" else typeof b.value)
  (* the operators a program is made of, each its own closure: two
   * numbers answered here, anything else Js_operators' *)
  | Binary ("+", a, b) ->
      let a = expr t a and b = expr t b in
      fun s this -> let p = a s this in let q = b s this in ( match (p, q) with Number x, Number y -> Number (x +. y) | _ -> Js_operators.arithmetic_simple "+" p q)
  | Binary ("-", a, b) ->
      let a = expr t a and b = expr t b in
      fun s this -> let p = a s this in let q = b s this in ( match (p, q) with Number x, Number y -> Number (x -. y) | _ -> Js_operators.arithmetic_simple "-" p q)
  | Binary ("*", a, b) ->
      let a = expr t a and b = expr t b in
      fun s this -> let p = a s this in let q = b s this in ( match (p, q) with Number x, Number y -> Number (x *. y) | _ -> Js_operators.arithmetic_simple "*" p q)
  | Binary ("<", a, b) ->
      let a = expr t a and b = expr t b in
      fun s this -> let p = a s this in let q = b s this in ( match (p, q) with Number x, Number y -> bool (x < y) | _ -> Js_operators.arithmetic_simple "<" p q)
  | Binary ("<=", a, b) ->
      let a = expr t a and b = expr t b in
      fun s this -> let p = a s this in let q = b s this in ( match (p, q) with Number x, Number y -> bool (x <= y) | _ -> Js_operators.arithmetic_simple "<=" p q)
  | Binary (">", a, b) ->
      let a = expr t a and b = expr t b in
      fun s this -> let p = a s this in let q = b s this in ( match (p, q) with Number x, Number y -> bool (x > y) | _ -> Js_operators.arithmetic_simple ">" p q)
  | Binary (">=", a, b) ->
      let a = expr t a and b = expr t b in
      fun s this -> let p = a s this in let q = b s this in ( match (p, q) with Number x, Number y -> bool (x >= y) | _ -> Js_operators.arithmetic_simple ">=" p q)
  | Binary ("===", a, b) ->
      let a = expr t a and b = expr t b in
      fun s this -> let p = a s this in let q = b s this in ( match (p, q) with Number x, Number y -> bool (x = y) | _ -> Js_operators.arithmetic_simple "===" p q)
  | Binary ("!==", a, b) ->
      let a = expr t a and b = expr t b in
      fun s this -> let p = a s this in let q = b s this in ( match (p, q) with Number x, Number y -> bool (x <> y) | _ -> Js_operators.arithmetic_simple "!==" p q)
  | Binary (op, a, b) -> (
      match binary op with
      | Some f -> let a = expr t a and b = expr t b in fun s this -> let x = a s this in f x (b s this)
      | None when op = "instanceof" -> let a = expr t a and b = expr t b in fun s this -> let x = a s this in bool (E.instance_of t x (b s this))
      | None -> walk)
  (* /re/: read once, a new object each time (it has its lastIndex) *)
  | Regex (source, flags) -> (
      match Js_regexp.compile source flags with
      | Ok re -> fun _ _ -> Js_builtins.regexp_value (E.protos t).regexps re
      | Error _ -> walk)
  | Logical ("&&", a, b) -> let a = expr t a and b = expr t b in fun s this -> let v = a s this in if truthy v then b s this else v
  | Logical ("??", a, b) -> let a = expr t a and b = expr t b in fun s this -> ( match a s this with Undefined | Null -> b s this | v -> v)
  | Logical (_, a, b) -> let a = expr t a and b = expr t b in fun s this -> let v = a s this in if truthy v then v else b s this
  | Conditional (c, a, b) -> let c = expr t c and a = expr t a and b = expr t b in fun s this -> if truthy (c s this) then a s this else b s this
  | Comma (a, b) -> let a = expr t a and b = expr t b in fun s this -> ignore (a s this); b s this
  (* an array's and a string's length, asked at each turn of a loop *)
  | Member (o, "length") -> (
      let o = expr t o in
      fun s this ->
        match o s this with
        | Object { kind = Array a; _ } -> Number (Float.of_int a.length)
        | String x -> Number (Float.of_int (Js_utf16.length x))
        | v -> E.get t v "length")
  | Member (o, k) -> let o = expr t o in fun s this -> E.get t (o s this) k
  (* o[k]: an array's item by a number at once, else the evaluator's *)
  | Index (o, k) -> (
      let o = expr t o and k = expr t k in
      fun s this ->
        let o = o s this in
        let k = k s this in
        match (o, k) with
        | Object { kind = Array a; _ }, Number f ->
            let i = Float.to_int f in
            if i >= 0 && i < a.length && Float.of_int i = f then Array.unsafe_get a.elements i else E.item t o k
        | _ -> E.item t o k)
  (* x = v: the binding set; one that is not there, or a constant, is
   * the evaluator's to say *)
  | Assign ("=", (Local (x, p) as target), v) ->
      let v = expr t v in
      fun s this ->
        if s.in_with then walk s this
        else
          let v = v s this in
          let b = Js_scope.at s x p in
          if b == Js_scope.nothing || b.constant then E.assign t s this target v else b.value <- v;
          v
  | Assign ("=", Member (o, k), v) -> let o = expr t o and v = expr t v in fun s this -> let o = o s this in let v = v s this in E.put t o k v; v
  | Assign ("=", Index (o, k), v) ->
      let o = expr t o and k = expr t k and v = expr t v in
      fun s this -> let o = o s this in let k = k s this in let v = v s this in E.put_item t o k v; v
  (* x += v, x++ *)
  | Assign (op, Local (x, p), v) when (match op with "=" | "&&=" | "||=" | "??=" -> false | _ -> true) -> (
      match binary (String.sub op 0 (String.length op - 1)) with
      | Some f ->
          let v = expr t v in
          fun s this ->
            let b = if s.in_with then Js_scope.nothing else Js_scope.at s x p in
            if b == Js_scope.nothing || b.constant then walk s this
            else (
              let old = b.value in
              let v = f old (v s this) in
              b.value <- v;
              v)
      | None -> walk)
  | Update (op, prefix, Local (x, p)) ->
      let by = if op = "++" then 1. else -1. in
      fun s this ->
        let b = if s.in_with then Js_scope.nothing else Js_scope.at s x p in
        if b == Js_scope.nothing || b.constant then walk s this
        else (
          let old = to_number b.value in
          b.value <- Number (old +. by);
          Number (if prefix then old +. by else old))
  (* f(a), o.m(a), o[k](a): the function and its this, the arguments,
   * then the call *)
  (* eval(text) by its name: the evaluator's, which runs it in this scope *)
  | Call ((Name "eval" | Local ("eval", _)), [ _ ]) -> walk
  | Call (f, args) when not (spread args) -> (
      let args = List.map (expr t) args in
      let call (fn : value) (self : value) (s : scope) (this : value) : value =
        let args = values args s this in
        if not (callable fn) then throw "TypeError" (E.describe f ^ " is not a function");
        E.call_in_run t fn ~this:self args
      in
      match f with
      | Member (o, k) ->
          let o = expr t o and array's = inherited k and string's = inherited k in
          fun s this ->
            let o = o s this in
            let fn =
              match o with
              | Object { kind = Array _; props = []; proto = None; _ } -> ( match array's (E.protos t).arrays with Some fn -> fn | None -> E.get t o k)
              | String _ -> ( match string's (E.protos t).strings with Some fn -> fn | None -> E.get t o k)
              | _ -> E.get t o k
            in
            call fn o s this
      | Index (o, k) -> let o = expr t o and k = expr t k in fun s this -> let o = o s this in call (E.item t o (k s this)) o s this
      | Opt _ | Super_member _ -> walk
      | f -> let f = expr t f in fun s this -> call (f s this) Undefined s this)
  | Function f -> fun s this -> E.closure s this f
  | Array es when not (spread es) -> let es = List.map (expr t) es in fun s this -> Object (new_array (values es s this))
  | _ -> walk

(*****************************************************************************)
(* Statements *)
(*****************************************************************************)

(* a loop's body ran: whether the loop goes on (None), or how it ends
 * (a loop with a label is the evaluator's) *)
and after (o : E.outcome) : E.outcome option = match o with Normal | Continue None -> None | Break None -> Some Normal | leave -> Some leave

and stmt (t : E.t) (st : A.stmt) : run =
  let line = st.line in
  let walk : run = fun s this -> E.exec t s this st in
  let plain decls = List.for_all (fun ((pt : A.pattern), _) -> match pt with Bind _ -> true | _ -> false) decls in
  match st.stmt with
  | Expr e -> let e = expr t e in fun s this -> E.step t line; ignore (e s this); Normal
  | Var_set decls ->
      let decls = List.map (fun (x, p, init) -> (x, p, Option.map (expr t) init)) decls in
      fun s this ->
        E.step t line;
        List.iter
          (fun (x, p, init) ->
            match init with
            | None -> if Js_scope.find s x p = None then Js_scope.declare s x ~constant:false Undefined
            | Some e -> (
                let v = e s this in
                match Js_scope.find s x p with Some b -> b.value <- v | None -> Js_scope.declare s x ~constant:false v))
          decls;
        Normal
  | Let (((Let_kind | Const_kind) as kind), decls) when plain decls ->
      let decls = List.concat_map (fun ((pt : A.pattern), init) -> match pt with Bind x -> [ (x, Option.map (expr t) init) ] | _ -> []) decls in
      let constant = kind = Const_kind in
      fun s this ->
        E.step t line;
        List.iter (fun (x, init) -> Js_scope.declare s x ~constant (match init with Some e -> e s this | None -> Undefined)) decls;
        Normal
  | Return None -> fun _ _ -> E.step t line; Return Undefined
  | Return (Some e) -> let e = expr t e in fun s this -> E.step t line; Return (e s this)
  | If (c, a, b) -> (
      let c = expr t c and a = inside t a in
      match b with
      | Some b -> let b = inside t b in fun s this -> E.step t line; if truthy (c s this) then a s this else b s this
      | None -> fun s this -> E.step t line; if truthy (c s this) then a s this else Normal)
  | While (c, body) ->
      let c = expr t c and body = inside t body in
      fun s this ->
        E.step t line;
        let rec loop () = if truthy (c s this) then match after (body s this) with None -> loop () | Some o -> o else Normal in
        loop ()
  | Do_while (body, c) ->
      let c = expr t c and body = inside t body in
      fun s this ->
        E.step t line;
        let rec loop () = match after (body s this) with None -> if truthy (c s this) then loop () else Normal | Some o -> o in
        loop ()
  (* for (let i ...): a scope for i, each turn in a copy of the last *)
  | For (init, test, update, body) ->
      let own = match init with Some { stmt = Let ((Let_kind | Const_kind), _); _ } -> true | _ -> false in
      let init = Option.map (stmt t) init and test = Option.map (expr t) test and update = Option.map (expr t) update and body = inside t body in
      fun s this ->
        E.step t line;
        let first = if own then Js_scope.nested s else s in
        Option.iter (fun i -> ignore (i first this)) init;
        let rec loop (it : scope) =
          let ok = match test with Some c -> truthy (c it this) | None -> true in
          if not ok then E.Normal
          else
            match after (body it this) with
            | Some o -> o
            | None ->
                let next = if own then Js_scope.copy it else it in
                Option.iter (fun u -> ignore (u next this)) update;
                loop next
        in
        loop first
  | Block body -> let b = block t ~scoped:true body in fun s this -> E.step t line; b s this
  (* the first case that is === the value, and from there every
   * statement to a break *)
  | Switch (e, cases) when not (List.exists (fun (_, body) -> functions body) cases) ->
      let e = expr t e in
      let tests = Array.of_list (List.map (fun (test, _) -> Option.map (expr t) test) cases) in
      let bodies = Array.of_list (List.map (fun (_, body) -> Array.of_list (List.map (stmt t) body)) cases) in
      let n = Array.length tests in
      let default = let rec go i = if i >= n then -1 else match tests.(i) with None -> i | Some _ -> go (i + 1) in go 0 in
      (* its scope: only if a case declares a name *)
      let scoped = List.exists (fun (_, body) -> E.declares body) cases in
      fun s this ->
        E.step t line;
        let v = e s this in
        let sc = if scoped then Js_scope.nested s else s in
        let rec from i = if i >= n then default else match tests.(i) with Some test when strict_equal v (test sc this) -> i | _ -> from (i + 1) in
        let rec go i j : E.outcome =
          if i >= n then Normal
          else if j >= Array.length bodies.(i) then go (i + 1) 0
          else match bodies.(i).(j) sc this with Normal -> go i (j + 1) | Break None -> Normal | o -> o
        in
        let start = from 0 in
        if start < 0 then Normal else go start 0
  | Throw e -> let e = expr t e in fun s this -> E.step t line; raise (Throw (e s this))
  (* finally runs however the rest ended, and its own ending wins if
   * it is not the normal one *)
  | Try (body, handler, finally) ->
      (* the evaluator gives each of the three a scope; here, one only
       * where a name is declared: the catch's own, a let *)
      let body = block t ~scoped:true body in
      let handler = Option.map (fun (x, h) -> (x, block t ~scoped:(x = None) h)) handler in
      let finally = Option.map (block t ~scoped:true) finally in
      fun s this ->
        E.step t line;
        let finish (ended : unit -> E.outcome) : E.outcome =
          match finally with
          | None -> ended ()
          | Some f -> (
              let run () = f s this in
              match ended () with
              | o -> ( match run () with Normal -> o | leave -> leave)
              | exception e -> ( match run () with Normal -> raise e | leave -> leave))
        in
        finish (fun () ->
            match body s this with
            | outcome -> outcome
            | exception Throw v when handler <> None ->
                let x, h = Option.get handler in
                (match x with
                | Some x ->
                    let scope = Js_scope.nested s in
                    Js_scope.declare scope x ~constant:false v;
                    h scope this
                | None -> h s this))
  | Function_decl _ | Empty -> fun _ _ -> E.step t line; Normal
  | Break l -> fun _ _ -> E.step t line; Break l
  | Continue l -> fun _ _ -> E.step t line; Continue l
  | _ -> walk

(* whether statements declare functions: made first, in their block *)
and functions (body : A.stmt list) : bool = List.exists (fun (st : A.stmt) -> match st.stmt with Function_decl _ | Export _ -> true | _ -> false) body

(* a branch's or a loop's body, in a scope of its own: a block makes its own *)
and inside (t : E.t) (st : A.stmt) : run =
  match st.stmt with
  | Block _ -> stmt t st
  (* the evaluator gives every other body a scope; only a declaration
   * can put a name in it: no scope made for the rest (116,000 a frame
   * of the Playground's menu, with switch's below) *)
  | Let _ | Class_decl _ | Function_decl _ | Export _ -> let r = stmt t st in fun s this -> r (Js_scope.nested s) this
  | _ -> stmt t st

(* statements one after the other, their functions first; [scoped]: in
 * a scope of their own if they declare a name (a block's; a
 * function's body and a try's are given theirs) *)
and block (t : E.t) ~(scoped : bool) (body : A.stmt list) : run = block_at ~top:false t ~scoped body

and block_at ~(top : bool) (t : E.t) ~(scoped : bool) (body : A.stmt list) : run =
  let fresh = scoped && E.declares body and functions = functions body in
  let codes = Array.of_list (List.map (stmt t) body) in
  let n = Array.length codes in
  fun s this ->
    let s = if fresh then Js_scope.nested s else s in
    if functions then E.declare_functions ~nested:(not top) s this body;
    let rec go i : E.outcome = if i >= n then Normal else match (Array.unsafe_get codes i) s this with Normal -> go (i + 1) | leave -> leave in
    go 0

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

let body (t : E.t) (f : A.func) : scope -> value -> value =
  let b = block_at ~top:true t ~scoped:false f.body in
  fun frame this -> match b frame this with Return v -> v | _ -> Undefined

let () = E.compiler := Some body
