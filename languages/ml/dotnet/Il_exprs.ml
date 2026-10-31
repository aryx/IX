(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Il_exprs.mli *)

module S = Signature
module W = Writer
open Il_code
open Il_types
open Il_functions
open Il_patterns

(*****************************************************************************)
(* Expressions *)
(*****************************************************************************)

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
  | Evar (Local v) when Hashtbl.mem env.by_var v.vid -> partial c env k e (Hashtbl.find env.by_var v.vid) []
  | Evar (Local v) -> if cts_of c e = S.Void then () else refuse e.loc (v.vname ^ ", a variable not compiled") "1c"
  | Evar (Global g) when Hashtbl.mem env.by_sym g.gsym -> partial c env k e (Hashtbl.find env.by_sym g.gsym) []
  (* a library function of one argument as a value (List.map
   * string_of_int): a class whose Invoke is its call *)
  | Evar (Global g)
    when builtin c g.gsym <> None && (match type_of e with Tarrow (_, Tarrow _) -> false | Tarrow _ -> true | _ -> false) ->
      let fty = type_of e in
      let a, b = match fty with Tarrow (a, b) -> (a, b) | _ -> assert false in
      let key = "builtin " ^ g.gsym in
      let ctor, inv =
        match Hashtbl.find_opt c.memo key with
        | Some ctor -> (ctor, Hashtbl.find c.memo (key ^ " invoke"))
        | None ->
            let t = helper_class c ("builtin_" ^ g.gname) 0 [] in
            let inv = W.method_def c.w t.tok "Invoke" 0x0086 (instance [ arg_type c e.loc a ] (arg_type c e.loc b)) in
            let k' = new_code () in
            if cts c e.loc a <> S.Void then emit k' (Il.Ldarg 1);
            (match builtin c g.gsym with Some ops -> List.iter (emit k') ops | None -> ());
            if cts c e.loc b = S.Void then emit k' Il.Ldnull;
            emit k' Il.Ret;
            finish c k' inv;
            Hashtbl.replace c.memo key t.ctor;
            Hashtbl.replace c.memo (key ^ " invoke") inv;
            (t.ctor, inv) in
      emit k (Il.Newobj ctor);
      emit k (Il.Ldftn inv);
      emit k (Il.Newobj (func_ctor c (cts c e.loc fty)))
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
  | Eapply ({ e = Evar (Prim (p, _, pty)); _ }, args) when Il_externals.is_dotnet p -> dotnet c env k e p pty args
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
      bindings c env k bs body;
      expr c env k body
  (* a local function that calls itself: its closure's own field *)
  | Elet (true, [ (Pvar v, ({ e = Efunction _; _ } as d)) ], body) ->
      lambda c env k d (Some v) (own_instance c v body);
      expr c env k body
  | Elet _ -> refuse e.loc "a let rec of several, or of a pattern, or let ... and" "1c"
  | Econstraint (e, _) -> expr c env k e
  | Efunction _ -> lambda c env k e None []
  | Ematch (scrut, cases) ->
      let v = local k (cts_of c scrut) in
      expr c env k scrut;
      emit k (Il.Stloc v);
      matching c env k e (fun () -> emit k (Il.Ldloc v)) (type_of scrut) cases
  | _ -> expr2 c env k e

(* let ... and ...: each bound in turn, none seeing another *)
and bindings (c : c) (env : env) (k : code) (bs : (Scope.pattern * Scope.expr) list) (body : Scope.expr) : unit =
      List.iter (fun ((p, d) : Scope.pattern * Scope.expr) ->
      (match simple p, d.e with
       | Some (Some _), _ when cts_of c d = S.Void -> drop c env k d
       | Some (Some v), Efunction _ -> bind c k v (fun () -> lambda c env k d None (own_instance c v body))
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
        bs

(* (expr's other cases: try, records, tuples, arrays) *)
and expr2 (c : c) (env : env) (k : code) (e : Scope.expr) : unit =
  match e.e with
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
  | Etuple es ->
      values c env k es;
      emit k (Il.Newobj (tuple_ctor c e.loc (type_of e)))
  (* [| a; b |]: newarr, each element stored *)
  | Earray es ->
      let elem = match cts_of c e with S.SzArray t -> t | _ -> refuse e.loc "an array of no array type" "1d" in
      let tok = type_token c elem in
      emit k (Il.Ldc_i4 (Int32.of_int (List.length es)));
      emit k (Il.Newarr tok);
      List.iteri
        (fun (i : int) (x : Scope.expr) ->
          emit k Il.Dup;
          emit k (Il.Ldc_i4 (Int32.of_int i));
          k.pending <- k.pending + 3;
          expr c env k x;
          if cts_of c x = S.Void then emit k Il.Ldnull;
          k.pending <- k.pending - 3;
          emit k (Il.Stelem_any tok))
        es
  | Eassert _ -> refuse e.loc "an assert" "1b"
  | _ -> expr c env k e

(* an expression in tail position, its value returned: every path ends
 * in ret, and a call there is a tail call (tail. call; ret: the
 * callee's frame in the caller's place, so that an ML loop, a tail
 * recursion, runs in a frame: the plan's decision 3). [boxed]: the
 * method returns an object for unit (a closure's Invoke), so a callee
 * returning nothing is called as any *)
and tail_expr (c : c) (env : env) (k : code) (e : Scope.expr) (boxed : bool) : unit =
  let plain () =
    expr c env k e;
    if boxed && cts_of c e = S.Void then emit k Il.Ldnull;
    emit k Il.Ret in
  let known (f : fn) (args : Scope.expr list) =
    List.length args = List.length f.params && not (boxed && cts c e.loc f.rty = S.Void) in
  match e.e with
  | Eif (cond, a, Some b) ->
      let otherwise = label k in
      expr c env k cond;
      emit k (Il.Brfalse otherwise);
      tail_expr c env k a boxed;
      place k otherwise;
      tail_expr c env k b boxed
  | Eseq (a, b) ->
      drop c env k a;
      tail_expr c env k b boxed
  | Elet (false, bs, body) ->
      bindings c env k bs body;
      tail_expr c env k body boxed
  | Elet (true, [ (Pvar v, ({ e = Efunction _; _ } as d)) ], body) ->
      lambda c env k d (Some v) (own_instance c v body);
      tail_expr c env k body boxed
  | Econstraint (x, _) -> tail_expr c env k x boxed
  | Ematch (scrut, cases) ->
      let v = local k (cts_of c scrut) in
      expr c env k scrut;
      emit k (Il.Stloc v);
      tail_cases c env k (fun () -> emit k (Il.Ldloc v)) (type_of scrut) cases boxed
  | Eapply (({ e = Evar (Global g); _ } as fe), args) when Hashtbl.mem env.by_sym g.gsym && known (Hashtbl.find env.by_sym g.gsym) args ->
      call_with c env k fe (Hashtbl.find env.by_sym g.gsym) args true;
      emit k Il.Ret
  | Eapply (({ e = Evar (Local v); _ } as fe), args) when Hashtbl.mem env.by_var v.vid && known (Hashtbl.find env.by_var v.vid) args ->
      call_with c env k fe (Hashtbl.find env.by_var v.vid) args true;
      emit k Il.Ret
  (* a function value: its last Invoke a tail call when its result is
   * what the method returns (an object, for unit) *)
  | Eapply (({ e = Evar (Local v); _ } as fe), args)
    when (Hashtbl.mem k.args v.vid || Hashtbl.mem k.slots v.vid || Hashtbl.mem k.captured v.vid) && (boxed || cts_of c e <> S.Void) ->
      expr c env k fe;
      invoke_tail c env k fe (type_of fe) args;
      emit k Il.Ret
  | _ -> plain ()

(* a match's cases, each body in tail position *)
and tail_cases (c : c) (env : env) (k : code) (load : unit -> unit) (ty : Scope.ty) (cases : Scope.case list) (boxed : bool) : unit =
  List.iter
    (fun ((p, guard, body) : Scope.case) ->
      let next = label k in
      pattern c k load ty p next;
      (match guard with Some g -> expr c env k g; emit k (Il.Brfalse next) | None -> ());
      tail_expr c env k body boxed;
      place k next)
    cases;
  match_failure c k

(* a function value's Invokes, the last after tail. *)
and invoke_tail (c : c) (env : env) (k : code) (at : Scope.expr) (fty : Scope.ty) (args : Scope.expr list) : unit =
  let ty = ref fty and n = List.length args in
  List.iteri
    (fun (i : int) (a : Scope.expr) ->
      let dom, codom = match !ty with Tarrow (x, y) -> (x, y) | _ -> refuse at.loc "an application of a non-function" "1c" in
      let fs = cts c at.loc !ty in
      k.pending <- k.pending + 1;
      expr c env k a;
      if cts c at.loc dom = S.Void then emit k Il.Ldnull;
      k.pending <- k.pending - 1;
      if i = n - 1 then emit k (Il.Prefix "tail.");
      emit k (Il.Callvirt (invoke c fs));
      ty := codom)
    args

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
  call_with c env k fe f args false

(* [tail]: all its arguments given, the call after tail. (the caller
 * then returns) *)
and call_with (c : c) (env : env) (k : code) (fe : Scope.expr) (f : fn) (args : Scope.expr list) (tail : bool) : unit =
  let n = List.length f.params in
  if List.length args < n then partial c env k fe f args
  else begin
    let mine = List.filteri (fun (i : int) (_ : Scope.expr) -> i < n) args in
    let more = List.filteri (fun (i : int) (_ : Scope.expr) -> i >= n) args in
    operands c env k mine;
    (* (a polymorphic function: its method instantiated at what the call
     * gives its type's variables, the call's own type said so) *)
    let ity = type_of fe in
    if tail then emit k (Il.Prefix "tail.");
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
and partial (c : c) (env : env) (k : code) (fe : Scope.expr) (f : fn) (args : Scope.expr list) : unit =
  let i = List.length args in
  let saved = k.pending in
  List.iteri
    (fun (j : int) (a : Scope.expr) ->
      expr c env k a;
      if cts c a.loc (List.nth f.ptys j) = S.Void then emit k Il.Ldnull;
      k.pending <- k.pending + 1)
    args;
  k.pending <- saved;
  (* (a polymorphic function's class at what the use gives its type's
   * variables, as a call's method) *)
  let ity = type_of fe in
  let inst =
    if f.gvars = [] then []
    else
      let m = instantiation (rest f 0) ity in
      List.map (fun (n : string) -> match List.assoc_opt n m with Some t -> arg_type c fe.loc t | None -> S.Object) f.gvars in
  let t, inv, sg = level c f i in
  let rec after (t : Scope.ty) (n : int) : Scope.ty = if n = 0 then t else match t with Tarrow (_, b) -> after b (n - 1) | t -> t in
  emit k (Il.Newobj (ctor_tok c t inst));
  emit k (Il.Ldftn (method_tok c t inst "Invoke" inv sg));
  emit k (Il.Newobj (func_ctor c (cts c fe.loc (after ity i))))

(* fun x -> ...: a class whose fields are the variables it captures (the
 * enclosing method's it names), its Invoke the function's body; the
 * value an object of it, as a Func. [self]: a let rec's name, a field
 * set to the Func itself, which the body calls *)
(* a local function's own type variables (let's polymorphism: its type
 * generalized apart from the enclosing function's), as its uses in the
 * let's body give them: a closure is not generic per call, so it is
 * compiled at the one type it is used at *)
and own_instance (c : c) (v : Scope.var) (body : Scope.expr) : (string * Scope.ty) list =
  match Typing.var_type v.vid with
  | None -> []
  | Some vty ->
      let own = List.filter (fun (n : string) -> not (List.mem_assoc n c.tvars)) (tvars_of vty) in
      if own = [] then []
      else begin
        let insts = List.map (fun (u : Scope.expr) -> instantiation vty (type_of u)) (uses v.vid body) in
        List.filter_map
          (fun (n : string) ->
            let at = List.filter_map (fun (m : (string * Scope.ty) list) -> List.assoc_opt n m) insts in
            let at = List.filter (fun (t : Scope.ty) -> match t with Tvar m -> m <> n | _ -> true) at in
            match at with
            | [] -> None
            | t :: rest ->
                let one = cts c 0 t in
                if List.exists (fun (t' : Scope.ty) -> cts c 0 t' <> one) rest then
                  refuse 0 (v.vname ^ ", a local function used at several types") "3a";
                Some (n, t))
          own
      end

and lambda (c : c) (env : env) (k : code) (e : Scope.expr) (self : Scope.var option) (aliases : (string * Scope.ty) list) : unit =
  let cases = match e.e with Efunction cases -> cases | _ -> refuse e.loc "a function" "1c" in
  let fty = type_of e in
  let dom, codom = match fty with Tarrow (a, b) -> (a, b) | _ -> refuse e.loc "a function" "1c" in
  let own = match self with Some v -> [ v.vid ] | None -> [] in
  let captured =
    List.filter
      (fun (vid : int) -> (Hashtbl.mem k.args vid || Hashtbl.mem k.slots vid || Hashtbl.mem k.captured vid) && not (List.mem vid own))
      (named e) in
  (* (inside a polymorphic function: the class generic in its type
   * variables, its own !0... there; made at the method's !!0...) *)
  let outer = c.tvars in
  let inner = List.mapi (fun (i : int) ((n, _) : string * S.t) -> (n, S.Var i)) outer in
  let at_outer = List.map snd outer in
  (* (its own variables, a local polymorphic function's, as its uses
   * give them, in each context) *)
  let outer' = outer @ List.map (fun ((n, t) : string * Scope.ty) -> (n, cts c e.loc t)) aliases in
  c.tvars <- inner;
  c.tvars <- inner @ List.map (fun ((n, t) : string * Scope.ty) -> (n, cts c e.loc t)) aliases;
  let types = List.map (fun (vid : int) -> match Typing.var_type vid with Some t -> cts c e.loc t | None -> S.Object) captured in
  let captured = List.filter (fun ((_, t) : int * S.t) -> t <> S.Void) (List.combine captured types) in
  incr closures;
  let fields = List.mapi (fun (i : int) ((_, t) : int * S.t) -> (Printf.sprintf "c%d" i, t)) captured in
  let fields = match self with Some v -> fields @ [ ("self_" ^ v.vname, cts c e.loc fty) ] | None -> fields in
  let t = helper_class c (Printf.sprintf "closure%d" !closures) (List.length outer) fields in
  let me = List.map snd inner in
  let sg = instance [ arg_type c e.loc dom ] (arg_type c e.loc codom) in
  let inv = W.method_def c.w t.tok "Invoke" 0x0086 sg in
  (* its body *)
  let k' = new_code () in
  List.iteri (fun (i : int) ((vid, _) : int * S.t) -> Hashtbl.replace k'.captured vid (field_tok c t me i)) captured;
  (match self with Some v -> Hashtbl.replace k'.captured v.vid (field_tok c t me (List.length captured)) | None -> ());
  (match cases with
   | [ (p, None, body) ] when (match p with Pvar _ | Pany | Pconstraint (Pvar _, _) -> true | Pcons (k'', []) -> k''.cname = "()" | _ -> false) ->
       (match p with Pvar v | Pconstraint (Pvar v, _) -> if cts c e.loc dom <> S.Void then Hashtbl.replace k'.args v.vid 1 | _ -> ());
       tail_expr c env k' body true
   | _ :: _ -> tail_cases c env k' (fun () -> emit k' (Il.Ldarg 1)) dom cases true
   | [] -> refuse e.loc "a function of no case" "1c");
  finish c k' inv;
  c.tvars <- outer';
  (* the value: the captured values, the object, the Func *)
  let saved = k.pending in
  List.iter (fun ((vid, _) : int * S.t) -> load_var k vid; k.pending <- k.pending + 1) captured;
  k.pending <- saved;
  (match self with Some _ -> emit k Il.Ldnull | None -> ());
  emit k (Il.Newobj (ctor_tok c t at_outer));
  let inv' = method_tok c t at_outer "Invoke" inv sg in
  let fs = cts c e.loc fty in
  match self with
  | None ->
      emit k (Il.Ldftn inv');
      emit k (Il.Newobj (func_ctor c fs));
      c.tvars <- outer
  | Some v ->
      let obj = local k (at t at_outer) and fslot = local k fs in
      emit k (Il.Stloc obj);
      emit k (Il.Ldloc obj);
      emit k (Il.Ldftn inv');
      emit k (Il.Newobj (func_ctor c fs));
      emit k (Il.Stloc fslot);
      Hashtbl.replace k.slots v.vid fslot;
      emit k (Il.Ldloc obj);
      emit k (Il.Ldloc fslot);
      emit k (Il.Stfld (field_tok c t at_outer (List.length captured)));
      c.tvars <- outer

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

(* a call of an external naming a .NET member (decision 7): its
 * arguments converted to its parameters' .NET types, its result back *)
and dotnet (c : c) (env : env) (k : code) (e : Scope.expr) (p : string) (pty : Scope.ty) (args : Scope.expr list) : unit =
  let m = Il_externals.member c e.loc p pty in
  let n = List.length (fst (Il_externals.arrows pty)) in
  if List.length args <> n then refuse e.loc (p ^ ", an external given fewer or more arguments than its type's") "3b";
  let saved = k.pending in
  let pending = ref (List.combine m.from m.into) in
  List.iter
    (fun (a : Scope.expr) ->
      expr c env k a;
      if cts_of c a <> S.Void then begin
        (match !pending with
         | (f, i) :: rest -> Il_externals.convert k f i; pending := rest
         | [] -> ());
        k.pending <- k.pending + 1
      end)
    args;
  k.pending <- saved;
  emit k (if m.static then Il.Call m.tok else Il.Callvirt m.tok);
  if m.ml_ret = S.Void && m.ret <> S.Void then emit k Il.Pop
  else Il_externals.convert k m.ret m.ml_ret

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
  (* an array's length, an element read and written (an index an
   * int32: IL's) *)
  | "%array_length", _ -> all (); emit k Il.Ldlen; emit k (Il.Conv (Il.K_i8, false, false))
  | ("%array_safe_get" | "%array_unsafe_get"), [ a; i ] ->
      let tok = match cts_of c a with S.SzArray t -> type_token c t | _ -> refuse e.loc "an array" "1d" in
      expr c env k a;
      k.pending <- k.pending + 1; expr c env k i; k.pending <- k.pending - 1;
      emit k (Il.Conv (Il.K_i4, false, false));
      emit k (Il.Ldelem_any tok);
      if cts_of c e = S.Void then emit k Il.Pop
  | ("%array_safe_set" | "%array_unsafe_set"), [ a; i; x ] ->
      let tok = match cts_of c a with S.SzArray t -> type_token c t | _ -> refuse e.loc "an array" "1d" in
      expr c env k a;
      k.pending <- k.pending + 1; expr c env k i; emit k (Il.Conv (Il.K_i4, false, false));
      k.pending <- k.pending + 1; expr c env k x; if cts_of c x = S.Void then emit k Il.Ldnull;
      k.pending <- k.pending - 2;
      emit k (Il.Stelem_any tok)
  | "%identity", _ -> all ()
  | "%ignore", [ a ] -> drop c env k a
  | "%raise", [ a ] -> expr c env k a; emit k Il.Throw
  (* (a primitive of the native runtime's C: the library's) *)
  | _ when String.length p > 0 && p.[0] <> '%' -> refuse e.loc ("the primitive " ^ p ^ ", of the library's runtime") "3"
  | _ -> refuse e.loc ("the primitive " ^ p) "1a"
