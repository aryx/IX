(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Fold.mli *)

let on = ref false
let bits = ref 63

(* the constants known, by their global's symbol: the unit's and the
 * summaries' *)
let constants : (string, Scope.exp) Hashtbl.t = Hashtbl.create 64
let own : (string * Scope.expr) list ref = ref []

let reset () = Hashtbl.reset constants; own := []
let import cs = List.iter (fun (g, (e : Scope.expr)) -> Hashtbl.replace constants g e.e) cs
let exports () = List.rev !own

(* a value copied where it is used: not a string (a block, each copy
 * another one) nor a float (a block too) *)
let constant (e : Scope.expr) =
  match e.e with
  | Econst (Int _ | Char _) | Econs ({ kind = Const _; _ }, []) -> true
  | _ -> false

let cons name k (t : Scope.ty) : Scope.cons =
  { cname = name; kind = Const k; arity = 0; nconst = (if name = "()" then 1 else 2); nblock = 0;
    ctype = [], [], t; cinline = [] }

let make (e : Scope.expr) (x : Scope.exp) : Scope.expr = { e with e = x }
let int e n = make e (Econst (Int n))
let bool e b = make e (Econs ((if b then cons "true" 1 Resolve.bool_t else cons "false" 0 Resolve.bool_t), []))

let truth (e : Scope.expr) =
  match e.e with
  | Econs ({ cname = "true" | "false"; kind = Const k; _ }, []) -> Some (k = 1)
  | _ -> None

(* the target's integer: its bits, wrapped as its arithmetic does; None
 * when the host's int cannot hold it (mini-ml on arm compiling for
 * arm64: not folded there, which only costs the fold) *)
let wrap n =
  let s = 64 - !bits in
  let n = Int64.shift_right (Int64.shift_left n s) s in
  if Int64.of_int (Int64.to_int n) = n then Some (Int64.to_int n) else None

(* (a shift by bits or more, or a division by zero: the program's own,
 * left to run) *)
let int2 p a b =
  let a = Int64.of_int a and b = Int64.of_int b in
  let shift f = if b >= 0L && b < Int64.of_int !bits then Some (f a (Int64.to_int b)) else None in
  let ones = Int64.sub (Int64.shift_left 1L !bits) 1L in
  Option.bind
    (match p with
     | "%addint" -> Some (Int64.add a b)
     | "%subint" -> Some (Int64.sub a b)
     | "%mulint" -> Some (Int64.mul a b)
     | "%divint" when b <> 0L -> Some (Int64.div a b)
     | "%modint" when b <> 0L -> Some (Int64.rem a b)
     | "%andint" -> Some (Int64.logand a b)
     | "%orint" -> Some (Int64.logor a b)
     | "%xorint" -> Some (Int64.logxor a b)
     | "%lslint" -> shift Int64.shift_left
     | "%asrint" -> shift Int64.shift_right
     | "%lsrint" -> shift (fun a k -> Int64.shift_right_logical (Int64.logand a ones) k)
     | _ -> None)
    wrap

let int1 p a =
  let a = Int64.of_int a in
  Option.bind
    (match p with
     | "%negint" -> Some (Int64.neg a)
     | "%succint" -> Some (Int64.succ a)
     | "%predint" -> Some (Int64.pred a)
     | "%lnot" -> Some (Int64.lognot a)
     | _ -> None)
    wrap

(* a comparison of two constants of one type, by their order *)
let key (e : Scope.expr) =
  match e.e with
  | Econst (Int n) -> Some n
  | Econst (Char c) -> Some (Char.code c)
  | Econs ({ kind = Const k; _ }, []) -> Some k
  | _ -> None

let rel p (a : int) b =
  match p with
  | "%equal" | "%eq" -> Some (a = b)
  | "%notequal" | "%noteq" -> Some (a <> b)
  | "%lessthan" -> Some (a < b)
  | "%lessequal" -> Some (a <= b)
  | "%greaterthan" -> Some (a > b)
  | "%greaterequal" -> Some (a >= b)
  | _ -> None

let rec expr (e : Scope.expr) : Scope.expr =
  let cases cs = List.map (fun (p, g, b) -> p, Option.map expr g, expr b) cs in
  let fields fs = List.map (fun (l, x) -> l, expr x) fs in
  match e.e with
  | Evar (Global g) -> (match Hashtbl.find_opt constants g.gsym with Some c -> make e c | None -> e)
  | Evar _ | Econst _ -> e
  | Eapply (f, es) -> apply e (expr f) (List.map expr es)
  | Eif (c, a, b) -> (
      let c = expr c in
      match truth c, b with
      | Some true, _ -> expr a
      | Some false, Some b -> expr b
      | Some false, None -> make e (Econs (cons "()" 0 Resolve.unit_t, []))
      | None, _ -> make e (Eif (c, expr a, Option.map expr b)))
  | Elet (r, bs, b) -> make e (Elet (r, List.map (fun (p, x) -> p, expr x) bs, expr b))
  | Efunction cs -> make e (Efunction (cases cs))
  | Ematch (x, cs) -> make e (Ematch (expr x, cases cs))
  | Etry (x, cs) -> make e (Etry (expr x, cases cs))
  | Etuple es -> make e (Etuple (List.map expr es))
  | Econs (c, es) -> make e (Econs (c, List.map expr es))
  | Erecord (n, fs) -> make e (Erecord (n, fields fs))
  | Ewith (x, n, fs) -> make e (Ewith (expr x, n, fields fs))
  | Efield (x, l) -> make e (Efield (expr x, l))
  | Esetfield (a, l, b) -> make e (Esetfield (expr a, l, expr b))
  | Earray es -> make e (Earray (List.map expr es))
  | Eseq (a, b) -> make e (Eseq (expr a, expr b))
  | Ewhile (a, b) -> make e (Ewhile (expr a, expr b))
  | Efor (v, a, b, d, body) -> make e (Efor (v, expr a, expr b, d, expr body))
  | Eassert x -> make e (Eassert (expr x))
  | Econstraint (x, t) -> make e (Econstraint (expr x, t))

(* a primitive of constants computed; && and || of a constant first *)
and apply (e : Scope.expr) (f : Scope.expr) (es : Scope.expr list) =
  let folded =
    match f.e, es with
    | Evar (Prim (("%sequand" | "%sequor") as p, 2, _)), [ a; b ] -> (
        match p, truth a with
        | "%sequand", Some true | "%sequor", Some false -> Some b
        | "%sequand", Some false | "%sequor", Some true -> Some a
        | _ -> None)
    | Evar (Prim ("%boolnot", 1, _)), [ a ] -> Option.map (fun t -> bool e (not t)) (truth a)
    | Evar (Prim (p, 2, _)), [ a; b ] -> (
        match key a, key b with
        | Some x, Some y -> (
            match rel p x y, a.e, b.e with
            | Some r, _, _ -> Some (bool e r)
            | None, Econst (Int x), Econst (Int y) -> Option.map (int e) (int2 p x y)
            | None, _, _ -> None)
        | _ -> None)
    | Evar (Prim (p, 1, _)), [ { e = Econst (Int x); _ } ] -> Option.map (int e) (int1 p x)
    | _ -> None
  in
  match folded with Some x -> x | None -> make e (Eapply (f, es))

let rec var (p : Scope.pattern) = match p with Pvar v -> Some v | Pconstraint (p, _) -> var p | _ -> None

let items (its : Scope.item list) =
  List.map (fun (it : Scope.item) ->
    match it with
    | Ieval e -> Scope.Ieval (expr e)
    | Ivalue (r, bs, gs) ->
        let bs = List.map (fun (p, e) -> p, expr e) bs in
        (match r, bs, gs with
         | false, [ (p, e) ], [ ((v : Scope.var), (g : Scope.global)) ]
           when constant e && Option.map (fun (x : Scope.var) -> x.vid) (var p) = Some v.vid ->
             Hashtbl.replace constants g.gsym e.e;
             own := (g.gsym, Summary.strip e) :: !own
         | _ -> ());
        Scope.Ivalue (r, bs, gs)
    | Iexception _ | Iexternal _ -> it) its
