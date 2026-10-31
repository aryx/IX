(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Lower_il.mli *)

module S = Signature
module W = Writer
open Il_code
open Il_types
open Il_functions
open Il_patterns

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
          let _, ctor, _, _ = case c e.loc k' (type_of e) in
          values c env k args;
          emit k (Il.Newobj ctor))
  | Evar (Local v) when Hashtbl.mem k.args v.vid || Hashtbl.mem k.slots v.vid || Hashtbl.mem k.captured v.vid -> load_var k v.vid
  (* (a function of the unit as a value: a Func) *)
  | Evar (Local v) when Hashtbl.mem env.by_var v.vid -> partial c env k (Hashtbl.find env.by_var v.vid) []
  | Evar (Local v) -> if cts_of c e = S.Void then () else refuse e.loc (v.vname ^ ", a variable not compiled") "1c"
  | Evar (Global g) when Hashtbl.mem env.by_sym g.gsym -> partial c env k (Hashtbl.find env.by_sym g.gsym) []
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
  | Eapply (({ e = Evar (Global g); _ } as fe), args) when Hashtbl.mem env.by_sym g.gsym -> call c env k fe (Hashtbl.find env.by_sym g.gsym) args
  | Eapply (({ e = Evar (Local v); _ } as fe), args) when Hashtbl.mem env.by_var v.vid -> call c env k fe (Hashtbl.find env.by_var v.vid) args
  | Eapply (({ e = Evar (Global g); _ } as f), args) when Hashtbl.mem env.fields g.gsym -> apply c env k f args
  | Eapply ({ e = Evar (Global g); _ }, args) -> (
      match builtin c g.gsym with
      | Some ops ->
          operands c env k args;
          List.iter (emit k) ops
      | None when String.length g.gsym > 11 && String.sub g.gsym 0 11 = "Pervasives." -> refuse e.loc (g.gsym ^ ", of the library") "3"
      | None -> refuse e.loc (g.gsym ^ ", of another unit") "1e")
  | Eapply (f, args) -> apply c env k f args
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
  | Elet (false, bs, body) ->
      (* (let ... and ...: each bound in turn, none seeing another) *)
      List.iter (fun ((p, d) : Scope.pattern * Scope.expr) ->
      (match simple p, d.e with
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
           place k ok))
        bs;
      expr c env k body
  (* a local function that calls itself: its closure's own field *)
  | Elet (true, [ (Pvar v, ({ e = Efunction _; _ } as d)) ], body) ->
      lambda c env k d (Some v);
      expr c env k body
  | Elet _ -> refuse e.loc "a let rec of several, or of a pattern, or let ... and" "1c"
  | Econstraint (e, _) -> expr c env k e
  | Efunction _ -> lambda c env k e None
  | Ematch (scrut, cases) ->
      let v = local k (cts_of c scrut) in
      expr c env k scrut;
      emit k (Il.Stloc v);
      matching c env k e (fun () -> emit k (Il.Ldloc v)) (type_of scrut) cases
  | Etry (body, cases) -> try_ c env k e body cases
  | Erecord (_, fs) ->
      (* (the fields' values in the class's order, its constructor's) *)
      let fs = List.sort (fun ((a, _) : Scope.label * Scope.expr) ((b, _) : Scope.label * Scope.expr) -> compare a.pos b.pos) fs in
      values c env k (List.map snd fs);
      emit k (Il.Newobj (record_ctor c e.loc (type_of e)))
  | Ewith (r, _, fs) ->
      let ty = type_of e in
      let d = decl ty in
      let labels = match Resolve.type_fields d with Some l -> List.map snd l | None -> [] in
      let labels = List.sort (fun (a : Scope.label) (b : Scope.label) -> compare a.pos b.pos) labels in
      let v = local k (cts_of c r) in
      expr c env k r;
      emit k (Il.Stloc v);
      List.iteri
        (fun (i : int) (l : Scope.label) ->
          k.pending <- k.pending + i;
          (match List.find_opt (fun ((l', _) : Scope.label * Scope.expr) -> l'.lname = l.lname) fs with
           | Some (_, x) -> expr c env k x; if cts_of c x = S.Void then emit k Il.Ldnull
           | None -> emit k (Il.Ldloc v); emit k (Il.Ldfld (field c e.loc ty l.lname)));
          k.pending <- k.pending - i)
        labels;
      emit k (Il.Newobj (record_ctor c e.loc ty))
  | Efield (r, l) ->
      expr c env k r;
      emit k (Il.Ldfld (field c e.loc (type_of r) l.lname));
      (* (a unit field's null) *)
      if cts_of c e = S.Void then emit k Il.Pop
  | Esetfield (r, l, x) ->
      values c env k [ r; x ];
      emit k (Il.Stfld (field c e.loc (type_of r) l.lname))
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

(* the values of a constructor's arguments, a record's fields: as
 * operands, unit's an object, null *)
and values (c : c) (env : env) (k : code) (es : Scope.expr list) : unit =
  let saved = k.pending in
  List.iter
    (fun (a : Scope.expr) ->
      expr c env k a;
      if cts_of c a = S.Void then emit k Il.Ldnull;
      k.pending <- k.pending + 1)
    es;
  k.pending <- saved

(* an expression for its effect: its value, if any, popped *)
and drop (c : c) (env : env) (k : code) (e : Scope.expr) : unit =
  expr c env k e;
  if cts_of c e <> S.Void then emit k Il.Pop

(* a call of a function of the unit: its method, all its arguments
 * given; fewer, a Func of those given (partial); more, its result
 * invoked with the others *)
and call (c : c) (env : env) (k : code) (fe : Scope.expr) (f : fn) (args : Scope.expr list) : unit =
  let n = List.length f.params in
  if List.length args < n then partial c env k f args
  else begin
    let mine = List.filteri (fun (i : int) (_ : Scope.expr) -> i < n) args in
    let more = List.filteri (fun (i : int) (_ : Scope.expr) -> i >= n) args in
    operands c env k mine;
    (* (a polymorphic function: its method instantiated at what the call
     * gives its type's variables, the call's own type said so) *)
    let ity = type_of fe in
    (if f.gvars = [] then emit k (Il.Call f.tok)
     else begin
       let inst = instantiation (rest f 0) ity in
       let args =
         List.map
           (fun (n : string) ->
             match List.assoc_opt n inst with
             | Some t ->
                 let t' = cts c fe.loc t in
                 if t' = S.Void then refuse fe.loc "a polymorphic function at unit" "1d";
                 t'
             | None -> S.Object)
           f.gvars in
       emit k (Il.Call (W.method_spec c.w f.tok args))
     end);
    let rec after (t : Scope.ty) (i : int) : Scope.ty = if i = 0 then t else match t with Tarrow (_, b) -> after b (i - 1) | t -> t in
    if more <> [] then invoke_with c env k fe (after ity n) more
  end

(* a variable's value: an argument, a local, a captured one (a field of
 * the closure, this) *)
and load_var (k : code) (vid : int) : unit =
  match Hashtbl.find_opt k.args vid, Hashtbl.find_opt k.slots vid, Hashtbl.find_opt k.captured vid with
  | Some i, _, _ -> emit k (Il.Ldarg i)
  | None, Some i, _ -> emit k (Il.Ldloc i)
  | None, None, Some f -> emit k (Il.Ldarg 0); emit k (Il.Ldfld f)
  | None, None, None -> ()

(* a function value applied: its Func invoked with each argument in
 * turn (unit's: null), the result of each the next Func *)
and apply (c : c) (env : env) (k : code) (f : Scope.expr) (args : Scope.expr list) : unit =
  expr c env k f;
  invoke_with c env k f (type_of f) args

and invoke_with (c : c) (env : env) (k : code) (at : Scope.expr) (fty : Scope.ty) (args : Scope.expr list) : unit =
  let ty = ref fty in
  List.iter
    (fun (a : Scope.expr) ->
      let dom, codom = match !ty with Tarrow (x, y) -> (x, y) | _ -> refuse at.loc "an application of a non-function" "1c" in
      let fs = cts c at.loc !ty in
      k.pending <- k.pending + 1;
      expr c env k a;
      if cts c at.loc dom = S.Void then emit k Il.Ldnull;
      k.pending <- k.pending - 1;
      emit k (Il.Callvirt (invoke c fs));
      ty := codom)
    args;
  (* (unit's value, a null object, not left) *)
  if cts c at.loc !ty = S.Void then emit k Il.Pop

(* a function of the unit given i arguments of its n: an object of a
 * class of its own holding them, its Invoke the next argument's (the
 * last calls the method), as a Func *)
and partial (c : c) (env : env) (k : code) (f : fn) (args : Scope.expr list) : unit =
  if f.gvars <> [] then refuse f.body.loc (f.fname ^ ", a polymorphic function given fewer arguments, or as a value") "1d";
  let i = List.length args in
  let saved = k.pending in
  List.iteri
    (fun (j : int) (a : Scope.expr) ->
      expr c env k a;
      if cts c a.loc (List.nth f.ptys j) = S.Void then emit k Il.Ldnull;
      k.pending <- k.pending + 1)
    args;
  k.pending <- saved;
  let _, ctor, inv = level c f i in
  emit k (Il.Newobj ctor);
  emit k (Il.Ldftn inv);
  emit k (Il.Newobj (func_ctor c (cts c 0 (rest f i))))

(* fun x -> ...: a class whose fields are the variables it captures (the
 * enclosing method's it names), its Invoke the function's body; the
 * value an object of it, as a Func. [self]: a let rec's name, a field
 * set to the Func itself, which the body calls *)
and lambda (c : c) (env : env) (k : code) (e : Scope.expr) (self : Scope.var option) : unit =
  if c.tvars <> [] then refuse e.loc "a closure inside a polymorphic function" "1d";
  let cases = match e.e with Efunction cases -> cases | _ -> refuse e.loc "a function" "1c" in
  let fty = type_of e in
  let dom, codom = match fty with Tarrow (a, b) -> (a, b) | _ -> refuse e.loc "a function" "1c" in
  let own = match self with Some v -> [ v.vid ] | None -> [] in
  let captured =
    List.filter
      (fun (vid : int) -> (Hashtbl.mem k.args vid || Hashtbl.mem k.slots vid || Hashtbl.mem k.captured vid) && not (List.mem vid own))
      (named e) in
  let types = List.map (fun (vid : int) -> match Typing.var_type vid with Some t -> cts c e.loc t | None -> S.Object) captured in
  let captured = List.filter (fun ((_, t) : int * S.t) -> t <> S.Void) (List.combine captured types) in
  incr closures;
  let fields = List.mapi (fun (i : int) ((_, t) : int * S.t) -> (Printf.sprintf "c%d" i, t)) captured in
  let fields = match self with Some v -> fields @ [ ("self_" ^ v.vname, cts c e.loc fty) ] | None -> fields in
  let cls, ctor, toks = new_class c "" (Printf.sprintf "closure%d" !closures) 0x00100102 (sys c "Object") (object_ctor c) [] fields in
  W.nest c.w cls c.cls;
  let inv = W.method_def c.w cls "Invoke" 0x0086 (instance [ arg_type c e.loc dom ] (arg_type c e.loc codom)) in
  (* its body *)
  let k' = new_code () in
  List.iteri (fun (i : int) ((vid, _) : int * S.t) -> Hashtbl.replace k'.captured vid (List.nth toks i)) captured;
  (match self with Some v -> Hashtbl.replace k'.captured v.vid (List.nth toks (List.length captured)) | None -> ());
  (match cases with
   | [ (p, None, body) ] when (match p with Pvar _ | Pany | Pconstraint (Pvar _, _) -> true | Pcons (k'', []) -> k''.cname = "()" | _ -> false) ->
       (match p with Pvar v | Pconstraint (Pvar v, _) -> if cts c e.loc dom <> S.Void then Hashtbl.replace k'.args v.vid 1 | _ -> ());
       expr c env k' body;
       if cts_of c body = S.Void then emit k' Il.Ldnull
   | (_, _, body) :: _ ->
       matching c env k' body (fun () -> emit k' (Il.Ldarg 1)) dom cases;
       if cts_of c body = S.Void then emit k' Il.Ldnull
   | [] -> refuse e.loc "a function of no case" "1c");
  emit k' Il.Ret;
  finish c k' inv;
  (* the value: the captured values, the object, the Func *)
  let saved = k.pending in
  List.iter (fun ((vid, _) : int * S.t) -> load_var k vid; k.pending <- k.pending + 1) captured;
  k.pending <- saved;
  (match self with Some _ -> emit k Il.Ldnull | None -> ());
  emit k (Il.Newobj ctor);
  match self with
  | None ->
      emit k (Il.Ldftn inv);
      emit k (Il.Newobj (func_ctor c (cts c e.loc fty)))
  | Some v ->
      let obj = local k (S.Class cls) and fslot = local k (cts c e.loc fty) in
      emit k (Il.Stloc obj);
      emit k (Il.Ldloc obj);
      emit k (Il.Ldftn inv);
      emit k (Il.Newobj (func_ctor c (cts c e.loc fty)));
      emit k (Il.Stloc fslot);
      Hashtbl.replace k.slots v.vid fslot;
      emit k (Il.Ldloc obj);
      emit k (Il.Ldloc fslot);
      emit k (Il.Stfld (List.nth toks (List.length captured)))

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
  (* both operands boxed (a type variable's value) *)
  let boxed () =
    let ty = first () in
    match args with
    | [ a; b ] ->
        expr c env k a; emit k (Il.Box (W.type_spec c.w ty));
        k.pending <- k.pending + 1; expr c env k b; emit k (Il.Box (W.type_spec c.w ty)); k.pending <- k.pending - 1
    | _ -> refuse e.loc "a comparison of a polymorphic value" "1d" in
  (* a comparison: a string's by CompareOrdinal against 0; a type
   * variable's by the assembly's Ml::compare *)
  let compare (lt : bool) (negate : bool) =
    (match first () with
    | S.String ->
        all ();
        emit k (Il.Call (lib c "String" "CompareOrdinal" (static [ S.String; S.String ] S.I4)));
        emit k (Il.Ldc_i4 0l)
    | S.MVar _ | S.Var _ ->
        boxed ();
        emit k (Il.Call (ml_compare c));
        emit k (Il.Ldc_i4 0l)
    | S.Class _ | S.GenericInst _ -> refuse e.loc "< on records or variants (OCaml's structural order)" "1d"
    | _ -> all ());
    (* (a float's NaN: unordered, so a <= b is not (a > b, or unordered)) *)
    let unordered = negate && first () = S.R8 in
    emit k (if lt then Il.Clt unordered else Il.Cgt unordered);
    if negate then (emit k (Il.Ldc_i4 0l); emit k Il.Ceq) in
  let equal () =
    match first () with
    | S.String -> op (Il.Call (lib c "String" "op_Equality" (static [ S.String; S.String ] S.Bool)))
    (* (a polymorphic function's value: boxed, its own Equals, an int's
     * or a record's) *)
    | (S.MVar _ | S.Var _) as t when p = "%equal" || p = "%notequal" ->
        let box () = emit k (Il.Box (W.type_spec c.w t)) in
        (match args with
         | [ a; b ] ->
             expr c env k a; box ();
             k.pending <- k.pending + 1; expr c env k b; box (); k.pending <- k.pending - 1;
             emit k (Il.Callvirt (lib c "Object" "Equals" (instance [ S.Object ] S.Bool)))
         | _ -> refuse e.loc "= of a polymorphic value" "1d")
    (* (a record's or a variant's Equals, structural; an exception's
     * the same object) *)
    | S.Class _ | S.GenericInst _ when p = "%equal" || p = "%notequal" -> op (Il.Callvirt (lib c "Object" "Equals" (instance [ S.Object ] S.Bool)))
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
  (* ref, !, :=, incr, decr: Pervasives' 'a ref, a record *)
  | "%makemutable", _ -> values c env k args; emit k (Il.Newobj (record_ctor c e.loc (type_of e)))
  | "%field0", [ r ] ->
      expr c env k r;
      emit k (Il.Ldfld (field0 c e.loc (type_of r)));
      if cts_of c e = S.Void then emit k Il.Pop
  | "%setfield0", [ r; _ ] -> values c env k args; emit k (Il.Stfld (field0 c e.loc (type_of r)))
  | ("%incr" | "%decr"), [ r ] ->
      let f = field0 c e.loc (type_of r) in
      expr c env k r;
      emit k Il.Dup;
      emit k (Il.Ldfld f);
      emit k (Il.Ldc_i8 1L);
      emit k (Il.Binop (if p = "%incr" then Il.Add else Il.Sub));
      emit k (Il.Stfld f)
  | "compare", [ _; _ ] -> (
      match first () with
      | S.MVar _ | S.Var _ | S.String | S.I8 | S.R8 | S.I4 | S.Bool ->
          (match first () with
           | S.MVar _ | S.Var _ -> boxed ()
           | ty ->
               let box = match ty with S.String -> [] | S.I8 -> [ Il.Box (sys c "Int64") ] | S.R8 -> [ Il.Box (sys c "Double") ] | S.I4 -> [ Il.Box (sys c "Int32") ] | _ -> [ Il.Box (sys c "Boolean") ] in
               (match args with
                | [ a; b ] ->
                    expr c env k a; List.iter (emit k) box;
                    k.pending <- k.pending + 1; expr c env k b; List.iter (emit k) box; k.pending <- k.pending - 1
                | _ -> ()));
          emit k (Il.Call (ml_compare c));
          emit k (Il.Conv (Il.K_i8, false, false))
      | _ -> refuse e.loc "compare on records or variants (OCaml's structural order)" "1d")
  | "%identity", _ -> all ()
  | "%ignore", [ a ] -> drop c env k a
  | "%raise", [ a ] -> expr c env k a; emit k Il.Throw
  | _ -> refuse e.loc ("the primitive " ^ p) "1a"

(*****************************************************************************)
(* A unit *)
(*****************************************************************************)

(* a function's method declared (a let rec's all first, so that each
 * calls the others), its body made later *)
let declare (c : c) (env : env) (globals : (Scope.var * Scope.global) list) (v : Scope.var) (d : Scope.expr) : fn =
  let ps, cases, body = params d in
  let rty = match cases with Some ((_, _, b) :: _) -> type_of b | _ -> type_of body in
  (* its type's variables: a generic method's parameters, !!0... *)
  let gvars = tvars_of (List.fold_right (fun ((_, a) : Scope.var option * Scope.ty) (b : Scope.ty) -> Scope.Tarrow (a, b)) ps rty) in
  c.tvars <- List.mapi (fun (i : int) (n : string) -> (n, S.MVar i)) gvars;
  let params = List.map (fun ((v, ty) : Scope.var option * Scope.ty) -> (v, cts c d.loc ty)) ps in
  let ret = if is_raise body then S.Void else cts c body.loc rty in
  let sg = { (static (List.filter (fun (t : S.t) -> t <> S.Void) (List.map snd params)) ret) with generic = List.length gvars } in
  c.tvars <- [];
  let tok = W.method_def c.w c.cls v.vname 0x0096 sg in
  List.iteri (fun (i : int) (_ : string) -> W.generic_param c.w tok i (Printf.sprintf "T%d" i)) gvars;
  let f = { tok; fname = v.vname; params; ptys = List.map snd ps; rty; cases; body; gvars } in
  Hashtbl.replace env.by_var v.vid f;
  (match global_of globals v with Some g -> Hashtbl.replace env.by_sym g.gsym f | None -> ());
  f

let define (c : c) (env : env) (f : fn) : unit =
  c.tvars <- List.mapi (fun (i : int) (n : string) -> (n, S.MVar i)) f.gvars;
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
       (* (its argument's own type: a constructor's pattern says the
        * declared one, 'a tree, not int tree) *)
       let pty = match List.rev f.ptys with t :: _ -> t | [] -> (match cases with (p, _, _) :: _ -> pattern_type p | [] -> Resolve.unit_t) in
       matching c env k f.body (fun () -> if arg >= 0 then emit k (Il.Ldarg arg)) pty cases);
  emit k Il.Ret;
  finish c k f.tok;
  c.tvars <- []

let unit_ (name : string) (items : Scope.item list) : string =
  let w = W.create name in
  let runtime = W.assembly_ref w "System.Runtime" in
  let console = W.type_ref w (W.assembly_ref w "System.Console") "System" "Console" in
  let obj = W.type_ref w runtime "System" "Object" in
  (* (a static class: abstract and sealed) *)
  let cls = W.type_def w "" name 0x00100181 obj in
  let c = { w; runtime; console; cls; uname = name; memo = Hashtbl.create 64; tvars = [] } in
  Il_types.reset ();
  closures := 0;
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
