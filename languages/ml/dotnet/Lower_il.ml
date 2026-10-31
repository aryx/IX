(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Lower_il.mli *)

module S = Signature
module W = Writer
open Il_code
open Il_types

(*****************************************************************************)
(* The unit's functions and values *)
(*****************************************************************************)

(* a function of the unit: its method, its arguments' variables (None:
 * unit's, or _), and when its last argument is a pattern or several
 * (function A -> ... | B -> ...), the cases on it; its body otherwise *)
type fn = { tok : int; params : (Scope.var option * S.t) list; cases : Scope.case list option; body : Scope.expr }

(* by variable (inside its definition, a let rec's) and by symbol
 * (after it, from the toplevel's later items); a value's field by
 * symbol *)
type env = { by_var : (int, fn) Hashtbl.t; by_sym : (string, fn) Hashtbl.t; fields : (string, int * S.t) Hashtbl.t }

let rec simple (p : Scope.pattern) : Scope.var option option =
  match p with
  | Pvar v -> Some (Some v)
  | Pany -> Some None
  | Pcons (k, []) when k.cname = "()" -> Some None
  | Pconstraint (p, _) -> simple p
  | _ -> None

(* a function's arguments, as its Efunction's nest; the last's cases
 * if it is matched *)
let rec params (e : Scope.expr) : (Scope.var option * Scope.ty) list * Scope.case list option * Scope.expr =
  match e.e with
  | Efunction cases ->
      let arg = match type_of e with Tarrow (a, _) -> a | _ -> refuse e.loc "a function" "1a" in
      (match cases with
       | [ (p, None, body) ] when simple p <> None ->
           let v = match simple p with Some v -> v | None -> None in
           let rest, cs, body = params body in
           ((v, arg) :: rest, cs, body)
       | (_, _, body) :: _ -> ([ (None, arg) ], Some cases, body)
       | [] -> refuse e.loc "a function of no case" "1a")
  | _ -> ([], None, e)

(*****************************************************************************)
(* Patterns *)
(*****************************************************************************)

(* a variable bound to the value [load] pushes, in a local of its own *)
let bind (c : c) (k : code) (v : Scope.var) (load : unit -> unit) : unit =
  let ty = match Typing.var_type v.vid with Some t -> cts c 0 t | None -> refuse 0 (v.vname ^ ", a variable whose type was not kept") "1a" in
  if ty <> S.Void then begin
    let i = match Hashtbl.find_opt k.slots v.vid with Some i -> i | None -> let i = local k ty in Hashtbl.replace k.slots v.vid i; i in
    load ();
    emit k (Il.Stloc i)
  end

(* the pattern tested on the value [load] pushes (of type [ty]): to
 * [fail] if it does not match, its variables bound if it does. A
 * value's parts are loaded again from it each time (a local, a field:
 * cheap), a constructor's after a cast to its class *)
let rec pattern (c : c) (k : code) (load : unit -> unit) (ty : Scope.ty) (p : Scope.pattern) (fail : int) : unit =
  match p with
  | Pany -> ()
  | Pvar v -> bind c k v load
  | Palias (p, v) ->
      pattern c k load ty p fail;
      bind c k v load
  | Pconstraint (p, _) -> pattern c k load ty p fail
  | Pconst (Int n) ->
      load ();
      emit k (Il.Ldc_i8 (Int64.of_int n));
      emit k (Il.Bcmp (Il.Ne, false, fail))
  | Pconst (Char ch) ->
      load ();
      emit k (Il.Ldc_i4 (Int32.of_int (Char.code ch)));
      emit k (Il.Bcmp (Il.Ne, false, fail))
  | Pconst (String s) ->
      load ();
      emit k (Il.Ldstr (W.user_string c.w s));
      emit k (Il.Call (lib c "String" "op_Equality" (static [ S.String; S.String ] S.Bool)));
      emit k (Il.Brfalse fail)
  | Pconst _ -> refuse 0 "a float, int32 or int64 constant as a pattern" "1d"
  | Prange (a, b) ->
      load ();
      emit k (Il.Ldc_i4 (Int32.of_int (Char.code a)));
      emit k (Il.Bcmp (Il.Lt, false, fail));
      load ();
      emit k (Il.Ldc_i4 (Int32.of_int (Char.code b)));
      emit k (Il.Bcmp (Il.Gt, false, fail))
  | Pcons (k', []) when k'.cname = "()" -> ()
  | Pcons (k', []) when k'.cname = "true" -> load (); emit k (Il.Brfalse fail)
  | Pcons (k', []) when k'.cname = "false" -> load (); emit k (Il.Brtrue fail)
  | Pcons (k', ps) ->
      let _, args, _ = k'.ctype in
      if List.length ps <> List.length args then refuse 0 (k'.cname ^ "'s arguments as one tuple") "1d";
      let cls, _, fld =
        match k'.kind with
        | Exn g -> exn c 0 g.gsym args
        | Const _ | Block _ -> case c 0 k' in
      load ();
      emit k (Il.Isinst cls);
      emit k (Il.Brfalse fail);
      List.iteri
        (fun (i : int) ((p, t) : Scope.pattern * Scope.ty) ->
          pattern c k (fun () -> load (); emit k (Il.Castclass cls); emit k (Il.Ldfld (fld i))) t p fail)
        (List.combine ps args)
  | Precord fs ->
      let d = match ty with Tconstr (d, _) -> d | _ -> refuse 0 "a record pattern" "1b" in
      List.iter
        (fun ((l, p) : Scope.label * Scope.pattern) ->
          let _, t, _ = l.ltype in
          pattern c k (fun () -> load (); emit k (Il.Ldfld (field c 0 d l.lname))) t p fail)
        fs
  | Por (a, b) ->
      let other = label k and ok = label k in
      pattern c k load ty a other;
      emit k (Il.Br ok);
      place k other;
      pattern c k load ty b fail;
      place k ok
  | Ptuple _ -> refuse 0 "a tuple pattern" "1d"

(*****************************************************************************)
(* Expressions *)
(*****************************************************************************)

(* the calls of Pervasives this stage has, as .NET's library's *)
let builtin (c : c) (sym : string) : Il.op list option =
  let write (t : S.t) = Il.Call (lib c "Console" "Write" (static [ t ] S.Void)) in
  let throw (name : string) =
    let _, ctor, _ = exn c 0 ("caml_exn_" ^ name) [ Resolve.string_t ] in
    [ Il.Newobj ctor; Il.Throw ] in
  match sym with
  | "Pervasives.print_int" -> Some [ write S.I8 ]
  | "Pervasives.print_string" -> Some [ write S.String ]
  | "Pervasives.print_char" -> Some [ Il.Conv (Il.K_u2, false, false); write S.Char ]
  | "Pervasives.print_endline" -> Some [ Il.Call (lib c "Console" "WriteLine" (static [ S.String ] S.Void)) ]
  | "Pervasives.print_newline" -> Some [ Il.Call (lib c "Console" "WriteLine" (static [] S.Void)) ]
  | "Pervasives.^" -> Some [ Il.Call (lib c "String" "Concat" (static [ S.String; S.String ] S.String)) ]
  (* (an int64 boxed, its ToString: Int64's own, by the object's class) *)
  | "Pervasives.string_of_int" -> Some [ Il.Box (sys c "Int64"); Il.Callvirt (lib c "Object" "ToString" (instance [] S.String)) ]
  | "Pervasives.failwith" -> Some (throw "Failure")
  | "Pervasives.invalid_arg" -> Some (throw "Invalid_argument")
  | _ -> None

let rec expr (c : c) (env : env) (k : code) (e : Scope.expr) : unit =
  match e.e with
  | Econst (Int n) -> emit k (Il.Ldc_i8 (Int64.of_int n))
  | Econst (Char ch) -> emit k (Il.Ldc_i4 (Int32.of_int (Char.code ch)))
  | Econst (String s) -> emit k (Il.Ldstr (W.user_string c.w s))
  | Econst (Float f) -> emit k (Il.Ldc_r (float_of_string f))
  | Econst _ -> refuse e.loc "an int32 or int64 constant" "1d"
  | Econs (k', []) when k'.cname = "()" -> ()
  | Econs (k', []) when k'.cname = "true" -> emit k (Il.Ldc_i4 1l)
  | Econs (k', []) when k'.cname = "false" -> emit k (Il.Ldc_i4 0l)
  | Econs (k', args) -> (
      let _, targs, _ = k'.ctype in
      if List.length args <> List.length targs then refuse e.loc (k'.cname ^ "'s arguments as one tuple") "1d";
      match k'.kind with
      | Exn g ->
          let _, ctor, _ = exn c e.loc g.gsym targs in
          operands c env k args;
          emit k (Il.Newobj ctor)
      | Const _ | Block _ ->
          let _, ctor, _ = case c e.loc k' in
          operands c env k args;
          emit k (Il.Newobj ctor))
  | Evar (Local v) -> (
      match Hashtbl.find_opt k.args v.vid, Hashtbl.find_opt k.slots v.vid with
      | Some i, _ -> emit k (Il.Ldarg i)
      | None, Some i -> emit k (Il.Ldloc i)
      | None, None -> if cts_of c e = S.Void then () else refuse e.loc (v.vname ^ ", a function as a value") "1c")
  | Evar (Global g) -> (
      match Hashtbl.find_opt env.fields g.gsym, g.gsym with
      | Some (f, ty), _ -> if ty <> S.Void then emit k (Il.Ldsfld f)
      | None, "Pervasives.nan" -> emit k (Il.Ldc_r nan)
      | None, "Pervasives.infinity" -> emit k (Il.Ldc_r infinity)
      | None, "Pervasives.neg_infinity" -> emit k (Il.Ldc_r neg_infinity)
      | None, _ -> (
          match type_of e with
          | Tarrow _ -> refuse e.loc (g.gsym ^ ", a function as a value") "1c"
          | _ -> refuse e.loc (g.gsym ^ ", a value of another unit") "1e"))
  | Evar (Prim (p, _, _)) -> refuse e.loc (p ^ ", a primitive as a value") "1c"
  | Eapply ({ e = Evar (Prim (p, _, _)); _ }, args) -> prim c env k e p args
  | Eapply ({ e = Evar (Global g); _ }, args) when Hashtbl.mem env.by_sym g.gsym -> call c env k e (Hashtbl.find env.by_sym g.gsym) args
  | Eapply ({ e = Evar (Local v); _ }, args) when Hashtbl.mem env.by_var v.vid -> call c env k e (Hashtbl.find env.by_var v.vid) args
  | Eapply ({ e = Evar (Global g); _ }, args) -> (
      match builtin c g.gsym with
      | Some ops ->
          operands c env k args;
          List.iter (emit k) ops
      | None when String.length g.gsym > 11 && String.sub g.gsym 0 11 = "Pervasives." -> refuse e.loc (g.gsym ^ ", of the library") "3"
      | None -> refuse e.loc (g.gsym ^ ", of another unit") "1e")
  | Eapply _ -> refuse e.loc "a call of a function value" "1c"
  | Eseq (a, b) ->
      drop c env k a;
      expr c env k b
  | Eif (cond, a, b) ->
      let otherwise = label k and over = label k in
      expr c env k cond;
      emit k (Il.Brfalse otherwise);
      expr c env k a;
      emit k (Il.Br over);
      place k otherwise;
      (match b with Some b -> expr c env k b | None -> ());
      place k over
  | Ewhile (cond, body) ->
      let top = label k and over = label k in
      place k top;
      expr c env k cond;
      emit k (Il.Brfalse over);
      drop c env k body;
      emit k (Il.Br top);
      place k over
  | Efor (v, a, b, dir, body) ->
      let i = local k S.I8 and last = local k S.I8 in
      Hashtbl.replace k.slots v.vid i;
      expr c env k a;
      emit k (Il.Stloc i);
      expr c env k b;
      emit k (Il.Stloc last);
      let top = label k and over = label k in
      place k top;
      emit k (Il.Ldloc i);
      emit k (Il.Ldloc last);
      (* (past the last: out) *)
      emit k (match dir with Upto -> Il.Cgt false | Downto -> Il.Clt false);
      emit k (Il.Brtrue over);
      drop c env k body;
      emit k (Il.Ldloc i);
      emit k (Il.Ldc_i8 1L);
      emit k (Il.Binop (match dir with Upto -> Il.Add | Downto -> Il.Sub));
      emit k (Il.Stloc i);
      emit k (Il.Br top);
      place k over
  | Elet (false, [ (p, d) ], body) ->
      (match simple p, d.e with
       | Some (Some v), Efunction _ -> refuse d.loc (v.vname ^ ", a local function") "1c"
       | Some (Some _), _ when cts_of c d = S.Void -> drop c env k d
       | Some (Some v), _ -> bind c k v (fun () -> expr c env k d)
       | Some None, _ -> drop c env k d
       | None, _ ->
           (* (a pattern: tested, Match_failure if it fails) *)
           let v = local k (cts_of c d) and fail = label k and ok = label k in
           expr c env k d;
           emit k (Il.Stloc v);
           pattern c k (fun () -> emit k (Il.Ldloc v)) (type_of d) p fail;
           emit k (Il.Br ok);
           place k fail;
           match_failure c k;
           place k ok);
      expr c env k body
  | Elet _ -> refuse e.loc "a let rec or let ... and" "1c"
  | Econstraint (e, _) -> expr c env k e
  | Efunction _ -> refuse e.loc "a function as a value" "1c"
  | Ematch (scrut, cases) ->
      let v = local k (cts_of c scrut) in
      expr c env k scrut;
      emit k (Il.Stloc v);
      matching c env k e (fun () -> emit k (Il.Ldloc v)) (type_of scrut) cases
  | Etry (body, cases) -> try_ c env k e body cases
  | Erecord (_, fs) ->
      let d = decl (type_of e) in
      (* (the fields' values in the class's order, its constructor's) *)
      let fs = List.sort (fun ((a, _) : Scope.label * Scope.expr) ((b, _) : Scope.label * Scope.expr) -> compare a.pos b.pos) fs in
      operands c env k (List.map snd fs);
      emit k (Il.Newobj (record_ctor c e.loc d))
  | Ewith (r, _, fs) ->
      let d = decl (type_of e) in
      let labels = match Resolve.type_fields d with Some l -> List.map snd l | None -> [] in
      let labels = List.sort (fun (a : Scope.label) (b : Scope.label) -> compare a.pos b.pos) labels in
      let v = local k (cts_of c r) in
      expr c env k r;
      emit k (Il.Stloc v);
      List.iteri
        (fun (i : int) (l : Scope.label) ->
          k.pending <- k.pending + i;
          (match List.find_opt (fun ((l', _) : Scope.label * Scope.expr) -> l'.lname = l.lname) fs with
           | Some (_, x) -> expr c env k x
           | None -> emit k (Il.Ldloc v); emit k (Il.Ldfld (field c e.loc d l.lname)));
          k.pending <- k.pending - i)
        labels;
      emit k (Il.Newobj (record_ctor c e.loc d))
  | Efield (r, l) ->
      expr c env k r;
      emit k (Il.Ldfld (field c e.loc (decl (type_of r)) l.lname))
  | Esetfield (r, l, x) ->
      operands c env k [ r; x ];
      emit k (Il.Stfld (field c e.loc (decl (type_of r)) l.lname))
  | Etuple _ -> refuse e.loc "a tuple" "1d"
  | Earray _ -> refuse e.loc "an array" "1d"
  | Eassert _ -> refuse e.loc "an assert" "1b"

(* operands, each left on the stack, the ones before it counted as
 * pending while it is made *)
and operands (c : c) (env : env) (k : code) (es : Scope.expr list) : unit =
  let saved = k.pending in
  List.iter
    (fun (a : Scope.expr) ->
      expr c env k a;
      if cts_of c a <> S.Void then k.pending <- k.pending + 1)
    es;
  k.pending <- saved

(* an expression for its effect: its value, if any, popped *)
and drop (c : c) (env : env) (k : code) (e : Scope.expr) : unit =
  expr c env k e;
  if cts_of c e <> S.Void then emit k Il.Pop

(* a call of a function of the unit, all its arguments given *)
and call (c : c) (env : env) (k : code) (e : Scope.expr) (f : fn) (args : Scope.expr list) : unit =
  if List.length args <> List.length f.params then refuse e.loc "a partial application" "1c";
  operands c env k args;
  emit k (Il.Call f.tok)

(* the cases tried in order on the value [load] pushes, the first that
 * matches (and whose guard holds) taken; its value in a local, read
 * after them; none: Match_failure *)
and matching (c : c) (env : env) (k : code) (e : Scope.expr) (load : unit -> unit) (ty : Scope.ty)
    (cases : Scope.case list) : unit =
  let rty = cts_of c e in
  let res = if rty <> S.Void then Some (local k rty) else None in
  let over = label k in
  List.iter
    (fun ((p, guard, body) : Scope.case) ->
      let next = label k in
      pattern c k load ty p next;
      (match guard with Some g -> expr c env k g; emit k (Il.Brfalse next) | None -> ());
      value c env k body res;
      emit k (Il.Br over);
      place k next)
    cases;
  match_failure c k;
  place k over;
  match res with Some r -> emit k (Il.Ldloc r) | None -> ()

(* an expression's value stored in [res] (none: dropped) *)
and value (c : c) (env : env) (k : code) (e : Scope.expr) (res : int option) : unit =
  match res with
  | Some r when not (is_raise e) -> expr c env k e; emit k (Il.Stloc r)
  | _ -> drop c env k e

(* try: the body in a protected region, any exception caught, the
 * handler's cases tried on it (as a match's), none: thrown again *)
and try_ (c : c) (env : env) (k : code) (e : Scope.expr) (body : Scope.expr) (cases : Scope.case list) : unit =
  if k.pending > 0 then refuse e.loc "a try inside an operand (made a variable's value first)" "1b";
  let rty = cts_of c e in
  let res = if rty <> S.Void then Some (local k rty) else None in
  let ex = local k (S.Class (sys c "Exception")) in
  let ts = label k and te = label k and hs = label k and he = label k and over = label k in
  place k ts;
  value c env k body res;
  emit k (Il.Leave over);
  place k te;
  place k hs;
  emit k (Il.Stloc ex);
  List.iter
    (fun ((p, guard, h) : Scope.case) ->
      let next = label k in
      pattern c k (fun () -> emit k (Il.Ldloc ex)) Resolve.exn_t p next;
      (match guard with Some g -> expr c env k g; emit k (Il.Brfalse next) | None -> ());
      value c env k h res;
      emit k (Il.Leave over);
      place k next)
    cases;
  emit k Il.Rethrow;
  place k he;
  k.clauses <- (ts, te, hs, he, sys c "Exception") :: k.clauses;
  place k over;
  match res with Some r -> emit k (Il.Ldloc r) | None -> ()

and prim (c : c) (env : env) (k : code) (e : Scope.expr) (p : string) (args : Scope.expr list) : unit =
  let all () = operands c env k args in
  let op (o : Il.op) = all (); emit k o in
  let first () : S.t = match args with a :: _ -> cts_of c a | [] -> S.Void in
  (* a comparison: a string's by CompareOrdinal against 0 *)
  let compare (lt : bool) (negate : bool) =
    if first () = S.String then begin
      all ();
      emit k (Il.Call (lib c "String" "CompareOrdinal" (static [ S.String; S.String ] S.I4)));
      emit k (Il.Ldc_i4 0l)
    end
    else all ();
    (* (a float's NaN: unordered, so a <= b is not (a > b, or unordered)) *)
    let unordered = negate && first () = S.R8 in
    emit k (if lt then Il.Clt unordered else Il.Cgt unordered);
    if negate then (emit k (Il.Ldc_i4 0l); emit k Il.Ceq) in
  let equal () =
    match first () with
    | S.String -> op (Il.Call (lib c "String" "op_Equality" (static [ S.String; S.String ] S.Bool)))
    (* (a record's or a variant's Equals, structural; an exception's
     * the same object) *)
    | S.Class _ when p = "%equal" || p = "%notequal" -> op (Il.Callvirt (lib c "Object" "Equals" (instance [ S.Object ] S.Bool)))
    | _ -> op Il.Ceq in
  match p, args with
  | ("%addint" | "%addfloat"), _ -> op (Il.Binop Il.Add)
  | ("%subint" | "%subfloat"), _ -> op (Il.Binop Il.Sub)
  | ("%mulint" | "%mulfloat"), _ -> op (Il.Binop Il.Mul)
  | ("%divint" | "%divfloat"), _ -> op (Il.Binop Il.Div)
  | "%modint", _ -> op (Il.Binop Il.Rem)
  | "%andint", _ -> op (Il.Binop Il.And)
  | "%orint", _ -> op (Il.Binop Il.Or)
  | "%xorint", _ -> op (Il.Binop Il.Xor)
  | ("%negint" | "%negfloat"), _ -> op Il.Neg
  | "%lnot", _ -> op Il.Not
  | "%succint", _ -> all (); emit k (Il.Ldc_i8 1L); emit k (Il.Binop Il.Add)
  | "%predint", _ -> all (); emit k (Il.Ldc_i8 1L); emit k (Il.Binop Il.Sub)
  (* (a shift's count an int32, IL's) *)
  | ("%lslint" | "%asrint" | "%lsrint"), _ ->
      all ();
      emit k (Il.Conv (Il.K_i4, false, false));
      emit k (Il.Binop (match p with "%lslint" -> Il.Shl | "%asrint" -> Il.Shr | _ -> Il.Shr_un))
  | "%floatofint", _ -> op (Il.Conv (Il.K_r8, false, false))
  | "%intoffloat", _ -> op (Il.Conv (Il.K_i8, false, false))
  | "%boolnot", _ -> all (); emit k (Il.Ldc_i4 0l); emit k Il.Ceq
  | ("%equal" | "%eq"), _ -> equal ()
  | ("%notequal" | "%noteq"), _ -> equal (); emit k (Il.Ldc_i4 0l); emit k Il.Ceq
  | "%lessthan", _ -> compare true false
  | "%greaterthan", _ -> compare false false
  | "%lessequal", _ -> compare false true
  | "%greaterequal", _ -> compare true true
  | "%sequand", [ a; b ] ->
      let no = label k and over = label k in
      expr c env k a;
      emit k (Il.Brfalse no);
      expr c env k b;
      emit k (Il.Br over);
      place k no;
      emit k (Il.Ldc_i4 0l);
      place k over
  | "%sequor", [ a; b ] ->
      let yes = label k and over = label k in
      expr c env k a;
      emit k (Il.Brtrue yes);
      expr c env k b;
      emit k (Il.Br over);
      place k yes;
      emit k (Il.Ldc_i4 1l);
      place k over
  | "%string_length", _ -> all (); emit k (Il.Callvirt (lib c "String" "get_Length" (instance [] S.I4))); emit k (Il.Conv (Il.K_i8, false, false))
  (* (s.[i]: String's Chars, a UTF-16 unit, a byte here: our char) *)
  | ("%string_safe_get" | "%string_unsafe_get"), [ s; i ] ->
      expr c env k s;
      k.pending <- k.pending + 1;
      expr c env k i;
      k.pending <- k.pending - 1;
      emit k (Il.Conv (Il.K_i4, false, false));
      emit k (Il.Callvirt (lib c "String" "get_Chars" (instance [ S.I4 ] S.Char)));
      emit k (Il.Conv (Il.K_i4, false, false))
  | "%identity", _ -> all ()
  | "%ignore", [ a ] -> drop c env k a
  | "%raise", [ a ] -> expr c env k a; emit k Il.Throw
  | _ -> refuse e.loc ("the primitive " ^ p) "1a"

(*****************************************************************************)
(* A unit *)
(*****************************************************************************)

let is_function (e : Scope.expr) : bool = match e.e with Efunction _ -> true | Econstraint ({ e = Efunction _; _ }, _) -> true | _ -> false

(* a toplevel variable's global *)
let global_of (globals : (Scope.var * Scope.global) list) (v : Scope.var) : Scope.global option =
  Option.map snd (List.find_opt (fun ((v', _) : Scope.var * Scope.global) -> v'.vid = v.vid) globals)

(* a function's method declared (a let rec's all first, so that each
 * calls the others), its body made later *)
let declare (c : c) (env : env) (globals : (Scope.var * Scope.global) list) (v : Scope.var) (d : Scope.expr) : fn =
  let ps, cases, body = params d in
  let params = List.map (fun ((v, ty) : Scope.var option * Scope.ty) -> (v, cts c d.loc ty)) ps in
  let ret = if is_raise body then S.Void else cts c body.loc (type_of body) in
  let sg = static (List.filter (fun (t : S.t) -> t <> S.Void) (List.map snd params)) ret in
  let tok = W.method_def c.w c.cls v.vname 0x0096 sg in
  let f = { tok; params; cases; body } in
  Hashtbl.replace env.by_var v.vid f;
  (match global_of globals v with Some g -> Hashtbl.replace env.by_sym g.gsym f | None -> ());
  f

(* a function's argument's type, from its first case's pattern: its
 * variable's, its constructor's, its record's *)
let rec pattern_type (p : Scope.pattern) : Scope.ty =
  match p with
  | Pvar v | Palias (_, v) -> (match Typing.var_type v.vid with Some t -> t | None -> Resolve.unit_t)
  | Pcons (k, _) -> let _, _, res = k.ctype in res
  | Precord ((l, _) :: _) -> let _, _, r = l.ltype in r
  | Pconstraint (p, _) | Por (p, _) -> pattern_type p
  | Pconst (Int _) -> Resolve.int_t
  | Pconst (String _) -> Resolve.string_t
  | Pconst (Char _) | Prange _ -> Resolve.char_t
  | _ -> Resolve.unit_t

let define (c : c) (env : env) (f : fn) : unit =
  let k = new_code () in
  let n = ref 0 and last = ref (-1) in
  List.iter
    (fun ((v, ty) : Scope.var option * S.t) ->
      if ty <> S.Void then begin
        (match v with Some v -> Hashtbl.replace k.args v.vid !n | None -> ());
        last := !n;
        incr n
      end)
    f.params;
  (match f.cases with
   | None -> expr c env k f.body
   | Some cases ->
       (* (the last argument matched: the function's cases a match's) *)
       let arg = !last in
       let pty = match cases with (p, _, _) :: _ -> pattern_type p | [] -> Resolve.unit_t in
       matching c env k f.body (fun () -> if arg >= 0 then emit k (Il.Ldarg arg)) pty cases);
  emit k Il.Ret;
  finish c k f.tok

let unit_ (name : string) (items : Scope.item list) : string =
  let w = W.create name in
  let runtime = W.assembly_ref w "System.Runtime" in
  let console = W.type_ref w (W.assembly_ref w "System.Console") "System" "Console" in
  let obj = W.type_ref w runtime "System" "Object" in
  (* (a static class: abstract and sealed) *)
  let cls = W.type_def w "" name 0x00100181 obj in
  let c = { w; runtime; console; cls; uname = name; memo = Hashtbl.create 64 } in
  Hashtbl.replace c.memo "type Object" obj;
  let env = { by_var = Hashtbl.create 16; by_sym = Hashtbl.create 16; fields = Hashtbl.create 16 } in
  let main = W.method_def w cls "Main" 0x0096 (static [] S.Void) in
  W.set_entry_point w main;
  let k = new_code () in
  let item (it : Scope.item) : unit =
    match it with
    | Ieval e -> drop c env k e
    | Ivalue (_, bs, globals) ->
        let fns =
          List.filter_map
            (fun ((p, d) : Scope.pattern * Scope.expr) ->
              match p with
              | (Pvar v | Pconstraint (Pvar v, _)) when is_function d -> Some (declare c env globals v d)
              | _ -> None)
            bs in
        List.iter (define c env) fns;
        List.iter
          (fun ((p, d) : Scope.pattern * Scope.expr) ->
            match p with
            | (Pvar v | Pconstraint (Pvar v, _)) when not (is_function d) -> (
                let ty = cts_of c d in
                expr c env k d;
                if ty <> S.Void then
                  match global_of globals v with
                  | Some g ->
                      let f = W.field_def w cls v.vname 0x0016 ty in
                      Hashtbl.replace env.fields g.gsym (f, ty);
                      emit k (Il.Stsfld f)
                  | None -> emit k Il.Pop)
            | Pvar _ | Pconstraint (Pvar _, _) -> ()
            | Pany | Pcons ({ cname = "()"; _ }, []) -> drop c env k d
            | _ -> refuse d.loc "a toplevel let of a pattern" "1d")
          bs
    (* (an exception's class is made when it is first raised or matched) *)
    | Iexception _ -> ()
    | Iexternal (g, _, _, _) -> refuse 0 ("the external " ^ g.gname) "1a" in
  List.iter item items;
  emit k Il.Ret;
  finish c k main;
  W.write w
