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

(* the primitives made values so far, a name each; the formats *)
let prim_values = ref 0
let format_values = ref 0

let is_format (t : Scope.ty) : bool =
  match t with Tconstr (d, _) -> d.tpath = "format4" || d.tpath = "format" | _ -> false

let rec expr (c : c) (env : env) (k : code) (e : Scope.expr) : unit =
  match e.e with
  | Econst (Int n) -> emit k (Il.Ldc_i8 (Int64.of_int n))
  | Econst (Char ch) -> emit k (Il.Ldc_i4 (Int32.of_int (Char.code ch)))
  | Econst (String s) when is_format (type_of e) -> format_value c env k e s
  | Econst (String s) -> emit k (Il.Ldstr (W.user_string c.w s))
  | Econst (Float f) -> emit k (Il.Ldc_r (float_of_string f))
  | Econst (Int64 s) -> emit k (Il.Ldc_i8 (Int64.of_string s))
  | Econst (Int32 s) -> emit k (Il.Ldc_i4 (Int32.of_string s))
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
  (* (a local function specialized: the closure of this use's types) *)
  | Evar (Local v) when Hashtbl.mem k.specs v.vid -> (
      let key = alias_key c (use_aliases c v e) in
      match List.find_opt (fun ((k', _, _) : string * spec * S.t) -> k' = key) (Hashtbl.find k.specs v.vid) with
      | Some (_, place, _) -> load_spec k place
      | None -> refuse e.loc (v.vname ^ ", a local function at a type of none of its uses") "3a")
  | Evar (Local v) when Hashtbl.mem k.args v.vid || Hashtbl.mem k.slots v.vid || Hashtbl.mem k.captured v.vid -> load_var k v.vid
  (* (a function of the unit as a value: a Func) *)
  | Evar (Local v) when Hashtbl.mem env.by_var v.vid -> partial c env k e (Hashtbl.find env.by_var v.vid) []
  | Evar (Local v) -> if cts_of c e = S.Void then () else refuse e.loc (v.vname ^ ", a variable not compiled") "1c"
  (* (another unit's external, its .mli's val: the primitive) *)
  | Evar (Global g) when Hashtbl.mem env.externals g.gsym ->
      let p, n, ty = Hashtbl.find env.externals g.gsym in
      expr c env k { e with e = Evar (Prim (p, n, ty)) }
  (* (a polymorphic value's method, of no argument: called) *)
  | Evar (Global g) when Hashtbl.mem env.by_sym g.gsym && (Hashtbl.find env.by_sym g.gsym).params = [] ->
      call c env k e e (Hashtbl.find env.by_sym g.gsym) []
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
  (* an external of C: the runtime unit's function of its name
   * (lib_core/dotnet/Runtime.ml, compiled first) *)
  | Evar (Prim (p, _, _)) when Hashtbl.mem env.by_sym ("Runtime." ^ p) -> partial c env k e (Hashtbl.find env.by_sym ("Runtime." ^ p)) []
  | Eapply (({ e = Evar (Prim (p, _, _)); _ } as fe), args) when Hashtbl.mem env.by_sym ("Runtime." ^ p) ->
      let f = Hashtbl.find env.by_sym ("Runtime." ^ p) in
      if not (Il_prims.runtime_call c k (compiler c env k) e f args) then call c env k e fe f args
  | Evar (Prim (p, n, _)) when not (Il_externals.is_dotnet p) -> prim_value c env k e p n
  | Evar (Prim (p, _, _)) -> refuse e.loc (p ^ ", a primitive as a value") "1c"
  (* (a primitive given fewer arguments than it takes, String.get s: the
   * primitive a value, applied; not %identity, whole with one, whatever
   * its type's arrows: Obj.magic's) *)
  | Eapply (({ e = Evar (Prim (p, n, _)); _ } as fe), args)
    when List.length args < n && p <> "%identity" && not (Il_externals.is_dotnet p) && not (Hashtbl.mem env.by_sym ("Runtime." ^ p)) ->
      apply c env k fe args
  (* (x |> f and f @@ x: f x, its type the application's) *)
  | Eapply ({ e = Evar (Prim ("%revapply", _, _)); _ }, x :: f :: more) -> expr c env k { e with e = Eapply (f, x :: more) }
  | Eapply ({ e = Evar (Prim ("%apply", _, _)); _ }, f :: x :: more) -> expr c env k { e with e = Eapply (f, x :: more) }
  | Eapply ({ e = Evar (Prim (p, _, pty)); _ }, args) when Il_externals.is_dotnet p -> Il_prims.dotnet c k (compiler c env k) e p pty args
  | Eapply ({ e = Evar (Prim (p, _, _)); _ }, args) -> Il_prims.prim c env k (compiler c env k) e p args
  | Eapply (({ e = Evar (Global g); _ } as fe), args) when Hashtbl.mem env.externals g.gsym ->
      let p, n, ty = Hashtbl.find env.externals g.gsym in
      expr c env k { e with e = Eapply ({ fe with e = Evar (Prim (p, n, ty)) }, args) }
  (* (Printf's functions with a literal format: compiled, Il_printf) *)
  | Eapply ({ e = Evar (Global g); _ }, args) when Il_printf.applies g.gsym args ->
      Il_printf.compile c env k (expr c env k) e g.gsym args
  (* (^ String.Concat, Pervasives' own or not: its ML copies twice) *)
  | Eapply (({ e = Evar (Global g); _ } as fe), args) when Hashtbl.mem env.by_sym g.gsym && g.gsym <> "Pervasives.^" ->
      call c env k e fe (Hashtbl.find env.by_sym g.gsym) args
  | Eapply (({ e = Evar (Local v); _ } as fe), args) when Hashtbl.mem env.by_var v.vid -> call c env k e fe (Hashtbl.find env.by_var v.vid) args
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
  | Elet (true, bs, body) when rec_functions bs ->
      lambdas c env k (rec_group c bs body);
      expr c env k body
  | Elet _ -> refuse e.loc "a let rec of several, or of a pattern, or let ... and" "1c"
  | Econstraint (e, _) -> expr c env k e
  | Efunction _ -> lambda c env k e None []
  (* (a unit's: evaluated, nothing to keep; the parser's match with
   * exception clauses matches one, its value made a variable) *)
  | Ematch (scrut, cases) when cts_of c scrut = S.Void ->
      drop c env k scrut;
      matching c env k e (fun () -> ()) (type_of scrut) cases
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
       (* (used at several types: a closure for each, in its local) *)
       | Some (Some v), Efunction _ when List.length (instances c v body) > 1 ->
           let specs = List.map (fun (a : (string * Scope.ty) list) ->
               let ty = cts c d.loc (subst (List.map fst a) (List.map snd a) (type_of d)) in
               let slot = local k ty in
               lambda c env k d None a;
               emit k (Il.Stloc slot);
               (alias_key c a, Slocal slot, ty)) (instances c v body) in
           Hashtbl.replace k.specs v.vid specs
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
  (* (Assert_failure (file, line, 0), as the native compiler's; assert
   * false of any type: a default value after, never reached) *)
  | Eassert x ->
      let ok = label k in
      expr c env k x;
      emit k (Il.Brtrue ok);
      let ty = Scope.Ttuple [ Resolve.string_t; Resolve.int_t; Resolve.int_t ] in
      emit k (Il.Ldstr (W.user_string c.w (c.uname ^ ".ml")));
      emit k (Il.Ldc_i8 (Int64.of_int e.loc));
      emit k (Il.Ldc_i8 0L);
      emit k (Il.Newobj (tuple_ctor c e.loc ty));
      (* (Pervasives' Assert_failure, which a handler names, when it is
       * in the assembly) *)
      let sym = if Hashtbl.mem c.memo "unit Pervasives" then "Pervasives.Assert_failure" else "caml_exn_Assert_failure" in
      let _, ctor, _ = exn c e.loc sym [ ty ] in
      emit k (Il.Newobj ctor);
      emit k Il.Throw;
      place k ok;
      Il_prims.default k (cts_of c e)
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
    (* (a call of unit, boxed: plain's null; its callee's result maybe a
     * type variable, failwith's 'a, so the call's own type asked too) *)
    List.length args = List.length f.params && not (boxed && (cts c e.loc f.rty = S.Void || cts_of c e = S.Void)) in
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
  | Elet (true, bs, body) when rec_functions bs ->
      lambdas c env k (rec_group c bs body);
      tail_expr c env k body boxed
  | Econstraint (x, _) -> tail_expr c env k x boxed
  | Ematch (scrut, cases) when cts_of c scrut = S.Void ->
      drop c env k scrut;
      tail_cases c env k (fun () -> ()) (type_of scrut) cases boxed
  | Ematch (scrut, cases) ->
      let v = local k (cts_of c scrut) in
      expr c env k scrut;
      emit k (Il.Stloc v);
      tail_cases c env k (fun () -> emit k (Il.Ldloc v)) (type_of scrut) cases boxed
  | Eapply (({ e = Evar (Global g); _ } as fe), args) when Hashtbl.mem env.by_sym g.gsym && known (Hashtbl.find env.by_sym g.gsym) args && not (Il_printf.applies g.gsym args) ->
      call_with c env k e fe (Hashtbl.find env.by_sym g.gsym) args true;
      emit k Il.Ret
  | Eapply (({ e = Evar (Local v); _ } as fe), args) when Hashtbl.mem env.by_var v.vid && known (Hashtbl.find env.by_var v.vid) args ->
      call_with c env k e fe (Hashtbl.find env.by_var v.vid) args true;
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
      let dom, codom = match unabbrev !ty with Tarrow (x, y) -> (x, y) | _ -> refuse at.loc "an application of a non-function" "1c" in
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
and call (c : c) (env : env) (k : code) (e : Scope.expr) (fe : Scope.expr) (f : fn) (args : Scope.expr list) : unit =
  call_with c env k e fe f args false

(* [tail]: all its arguments given, the call after tail. (the caller
 * then returns) *)
and call_with (c : c) (env : env) (k : code) (e : Scope.expr) (fe : Scope.expr) (f : fn) (args : Scope.expr list) (tail : bool) : unit =
  let n = List.length f.params in
  if List.length args < n then partial c env k fe f args
  else begin
    let mine = List.filteri (fun (i : int) (_ : Scope.expr) -> i < n) args in
    let more = List.filteri (fun (i : int) (_ : Scope.expr) -> i >= n) args in
    (* (a unit for a parameter of a type variable: null, F#'s unit as a
     * type argument, an object) *)
    let saved = k.pending in
    List.iter2
      (fun (a : Scope.expr) ((_, t) : Scope.var option * S.t) ->
        expr c env k a;
        let unit_ = cts_of c a = S.Void in
        if unit_ && (match t with S.MVar _ -> true | _ -> false) then emit k Il.Ldnull;
        if not unit_ || t <> S.Void then k.pending <- k.pending + 1)
      mine f.params;
    k.pending <- saved;
    (* (a polymorphic function: its method instantiated at what the call
     * gives its type's variables, the call's own type said so; unit
     * an object, its result then dropped) *)
    let ity = type_of fe in
    let rec after (t : Scope.ty) (i : int) : Scope.ty = if i = 0 then t else match unabbrev t with Tarrow (_, b) -> after b (i - 1) | t -> t in
    let drop_result =
      f.gvars <> [] && more = [] && not (raises_always f)
      && (match f.rty with Tvar _ -> true | _ -> false) && cts c fe.loc (after ity n) = S.Void in
    (* (a method of nothing, unit's or a raise's, where a value is
     * wanted, a type variable's in an Obj.magic: a default value) *)
    let void_callee = raises_always f || cts c fe.loc f.rty = S.Void in
    let raises = void_callee && more = [] && cts_of c e <> S.Void in
    if tail && not drop_result && not raises then emit k (Il.Prefix "tail.");
    (if f.gvars = [] then emit k (Il.Call f.tok)
     else begin
       let inst = instantiation (rest f 0) ity in
       let args =
         List.map
           (fun (n : string) ->
             match List.assoc_opt n inst with
             | Some t -> arg_type c fe.loc t
             | None -> S.Object)
           f.gvars in
       emit k (Il.Call (W.method_spec c.w f.tok args))
     end);
    if drop_result then emit k Il.Pop;
    if raises then Il_prims.default k (cts_of c e);
    if more <> [] then invoke_with c env k fe (after ity n) more
  end

(* a specialized closure's value: its local, or its field of this *)
and load_spec (k : code) (place : spec) : unit =
  match place with
  | Slocal slot -> emit k (Il.Ldloc slot)
  | Sfield f -> emit k (Il.Ldarg 0); emit k (Il.Ldfld f)

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
      let dom, codom = match unabbrev !ty with Tarrow (x, y) -> (x, y) | _ -> refuse at.loc "an application of a non-function" "1c" in
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
  let rec after (t : Scope.ty) (n : int) : Scope.ty = if n = 0 then t else match unabbrev t with Tarrow (_, b) -> after b (n - 1) | t -> t in
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
(* a local function's use: the types it gives its own variables (those
 * not of the enclosing function), and their key *)
and use_aliases (c : c) (v : Scope.var) (u : Scope.expr) : (string * Scope.ty) list =
  match Il_types.var_type v.vid with
  | None -> []
  | Some vty ->
      let own = List.filter (fun (n : string) -> not (List.mem_assoc n c.tvars)) (tvars_of vty) in
      let m = instantiation vty (type_of u) in
      List.filter_map (fun (n : string) ->
          match List.assoc_opt n m with Some (Tvar n') when n' = n -> None | Some t -> Some (n, t) | None -> None) own

and alias_key (c : c) (aliases : (string * Scope.ty) list) : string =
  String.concat "," (List.map (fun ((n, t) : string * Scope.ty) -> n ^ "=" ^ S.encode_type_spec (arg_type c 0 t)) aliases)

(* a local function's instances, by its uses' types: several when it is
 * used at several (let's polymorphism: Check's one, of a list of two
 * types), each then a closure of its own (specialize) *)
and instances (c : c) (v : Scope.var) (body : Scope.expr) : (string * Scope.ty) list list =
  let seen = Hashtbl.create 4 in
  List.filter_map (fun (u : Scope.expr) ->
      let a = use_aliases c v u in
      let key = alias_key c a in
      if Hashtbl.mem seen key then None else (Hashtbl.replace seen key (); Some a))
    (uses v.vid body)

and own_instance (c : c) (v : Scope.var) (body : Scope.expr) : (string * Scope.ty) list =
  match Il_types.var_type v.vid with
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
  match self with
  | Some v -> lambdas c env k [ (v, e, aliases) ]
  | None ->
      let outer = c.tvars in
      let t, at_outer, inv', fs, captured, specs = closure c env k e [] aliases in
      let saved = k.pending in
      List.iter (fun ((vid, _) : int * S.t) -> load_var k vid; k.pending <- k.pending + 1) captured;
      List.iter (fun ((_, place, _) : string * spec * S.t) -> load_spec k place; k.pending <- k.pending + 1) specs;
      k.pending <- saved;
      emit k (Il.Newobj (ctor_tok c t at_outer));
      emit k (Il.Ldftn inv');
      emit k (Il.Newobj (func_ctor c fs));
      c.tvars <- outer

(* a closure's class and its Invoke; [group]: the functions of a let
 * rec it is one of, each a field of it (null when it is made, then
 * set: lambdas). Its class, the type arguments it is made at, its
 * Invoke, its Func's type, what it captures *)
and closure (c : c) (env : env) (k : code) (e : Scope.expr) (group : (Scope.var * Scope.ty) list) (aliases : (string * Scope.ty) list)
    : tclass * S.t list * int * S.t * (int * S.t) list * (string * spec * S.t) list =
  let cases = match e.e with Efunction cases -> cases | _ -> refuse e.loc "a function" "1c" in
  let fty = type_of e in
  let dom, codom = match unabbrev fty with Tarrow (a, b) -> (a, b) | _ -> refuse e.loc "a function" "1c" in
  let own = List.map (fun ((v, _) : Scope.var * Scope.ty) -> v.vid) group in
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
  let outer' = outer @ List.map (fun ((n, t) : string * Scope.ty) -> (n, arg_type c e.loc t)) aliases in
  (* (the aliases' types in the class's variables: inner first) *)
  c.tvars <- inner;
  c.tvars <- inner @ List.map (fun ((n, t) : string * Scope.ty) -> (n, arg_type c e.loc t)) aliases;
  let types = List.map (fun (vid : int) -> match Il_types.var_type vid with Some t -> cts c e.loc t | None -> S.Object) captured in
  let captured = List.filter (fun ((_, t) : int * S.t) -> t <> S.Void) (List.combine captured types) in
  incr closures;
  (* (a local function specialized, named here: each of its closures a
   * field, after the variables') *)
  let spec_vids = List.filter (fun (vid : int) -> Hashtbl.mem k.specs vid && not (List.mem vid own)) (named e) in
  let spec_caps = List.concat_map (fun (vid : int) ->
      List.map (fun ((key, place, ty) : string * spec * S.t) -> (vid, key, place, ty)) (Hashtbl.find k.specs vid)) spec_vids in
  let fields = List.mapi (fun (i : int) ((_, t) : int * S.t) -> (Printf.sprintf "c%d" i, t)) captured in
  let fields = fields @ List.mapi (fun (i : int) ((_, _, _, t) : int * string * spec * S.t) -> (Printf.sprintf "s%d" i, t)) spec_caps in
  let fields = fields @ List.map (fun ((v, ty) : Scope.var * Scope.ty) -> ("self_" ^ v.vname, cts c e.loc ty)) group in
  let t = helper_class c (Printf.sprintf "closure%d" !closures) (List.length outer) fields in
  let me = List.map snd inner in
  let sg = instance [ arg_type c e.loc dom ] (arg_type c e.loc codom) in
  let inv = W.method_def c.w t.tok "Invoke" 0x0086 sg in
  (* its body *)
  let k' = new_code () in
  List.iteri (fun (i : int) ((vid, _) : int * S.t) -> Hashtbl.replace k'.captured vid (field_tok c t me i)) captured;
  List.iteri (fun (j : int) ((vid, key, _, ty) : int * string * spec * S.t) ->
      let f = field_tok c t me (List.length captured + j) in
      let before = match Hashtbl.find_opt k'.specs vid with Some l -> l | None -> [] in
      Hashtbl.replace k'.specs vid (before @ [ (key, Sfield f, ty) ])) spec_caps;
  let nspec = List.length spec_caps in
  List.iteri (fun (j : int) ((v, _) : Scope.var * Scope.ty) -> Hashtbl.replace k'.captured v.vid (field_tok c t me (List.length captured + nspec + j))) group;
  (match cases with
   | [ (p, None, body) ] when (match p with Pvar _ | Pany | Pconstraint (Pvar _, _) -> true | Pcons (k'', []) -> k''.cname = "()" | _ -> false) ->
       (match p with Pvar v | Pconstraint (Pvar v, _) -> if cts c e.loc dom <> S.Void then Hashtbl.replace k'.args v.vid 1 | _ -> ());
       tail_expr c env k' body true
   | _ :: _ -> tail_cases c env k' (fun () -> emit k' (Il.Ldarg 1)) dom cases true
   | [] -> refuse e.loc "a function of no case" "1c");
  finish c k' inv;
  c.tvars <- outer';
  let inv' = method_tok c t at_outer "Invoke" inv sg in
  let fs = cts c e.loc fty in
  (t, at_outer, inv', fs, captured, List.map (fun ((_, key, place, ty) : int * string * spec * S.t) -> (key, place, ty)) spec_caps)

(* a let rec's bindings all functions, of variables *)
and rec_functions (bs : (Scope.pattern * Scope.expr) list) : bool =
  List.for_all
    (fun ((p, d) : Scope.pattern * Scope.expr) ->
      match p, d.e with (Pvar _ | Pconstraint (Pvar _, _)), Efunction _ -> true | _ -> false)
    bs

and rec_group (c : c) (bs : (Scope.pattern * Scope.expr) list) (body : Scope.expr) : (Scope.var * Scope.expr * (string * Scope.ty) list) list =
  List.map
    (fun ((p, d) : Scope.pattern * Scope.expr) ->
      match p with
      | Pvar v | Pconstraint (Pvar v, _) -> (v, d, own_instance c v body)
      | _ -> refuse d.loc "a let rec of a pattern" "1c")
    bs

(* a let rec of functions (one, or several calling each other): each a
 * closure whose fields hold the group's Funcs; all made first, their
 * Funcs in locals (the variables), then each one's fields set *)
and lambdas (c : c) (env : env) (k : code) (defs : (Scope.var * Scope.expr * (string * Scope.ty) list) list) : unit =
  let outer = c.tvars in
  let group = List.map (fun ((v, d, _) : Scope.var * Scope.expr * (string * Scope.ty) list) -> (v, type_of d)) defs in
  let made =
    List.map
      (fun ((v, d, aliases) : Scope.var * Scope.expr * (string * Scope.ty) list) ->
        let t, at_outer, inv', fs, captured, specs = closure c env k d group aliases in
        let saved = k.pending in
        List.iter (fun ((vid, _) : int * S.t) -> load_var k vid; k.pending <- k.pending + 1) captured;
        List.iter (fun ((_, place, _) : string * spec * S.t) -> load_spec k place; k.pending <- k.pending + 1) specs;
        k.pending <- saved;
        List.iter (fun (_ : Scope.var * Scope.ty) -> emit k Il.Ldnull) group;
        emit k (Il.Newobj (ctor_tok c t at_outer));
        let obj = local k (at t at_outer) and fslot = local k fs in
        emit k (Il.Stloc obj);
        emit k (Il.Ldloc obj);
        emit k (Il.Ldftn inv');
        emit k (Il.Newobj (func_ctor c fs));
        emit k (Il.Stloc fslot);
        c.tvars <- outer;
        (v, t, at_outer, obj, fslot, List.length captured + List.length specs))
      defs in
  List.iter (fun ((v, _, _, _, fslot, _) : Scope.var * tclass * S.t list * int * int * int) -> Hashtbl.replace k.slots v.vid fslot) made;
  List.iter
    (fun ((_, t, at_outer, obj, _, n) : Scope.var * tclass * S.t list * int * int * int) ->
      List.iteri
        (fun (j : int) ((_, _, _, _, fslot, _) : Scope.var * tclass * S.t list * int * int * int) ->
          emit k (Il.Ldloc obj);
          emit k (Il.Ldloc fslot);
          emit k (Il.Stfld (field_tok c t at_outer (n + j))))
        made)
    made

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

(* a primitive as a value (let equal = (=)): η-expanded, a method of
 * the unit, prim_N x1 ... xn = p x1 ... xn, at the use's type, made a
 * Func as a function given none of its arguments (partial) *)
and prim_value (c : c) (env : env) (k : code) (e : Scope.expr) (p : string) (n : int) : unit =
  let ty = type_of e in
  (* (at a type variable, compare in a polymorphic function: the
   * method generic in them, made at the use's types by partial) *)
  let outer = c.tvars in
  let gvars = tvars_of ty in
  c.tvars <- List.mapi (fun (i : int) (n : string) -> (n, S.MVar i)) gvars;
  let rec split (t : Scope.ty) (i : int) : Scope.ty list * Scope.ty =
    if i = 0 then ([], t) else match t with Tarrow (a, b) -> let l, r = split b (i - 1) in (a :: l, r) | t -> ([], t) in
  let ptys, rty = split ty n in
  incr prim_values;
  let id = !prim_values in
  let fresh (t : Scope.ty) (x : Scope.exp) : Scope.expr =
    incr prim_values;
    let ex : Scope.expr = { e = x; loc = e.loc; span = (- !prim_values, - id) } in
    Hashtbl.replace synthetic ex.span t;
    ex in
  let vars = List.mapi (fun (i : int) (_ : Scope.ty) -> ({ vname = Printf.sprintf "x%d" i; vid = - 1000000 * id - i } : Scope.var)) ptys in
  let fe = fresh ty (Evar (Prim (p, n, ty))) in
  let body = fresh rty (Eapply (fe, List.map2 (fun (v : Scope.var) (t : Scope.ty) -> fresh t (Evar (Local v))) vars ptys)) in
  let params = List.map2 (fun (v : Scope.var) (t : Scope.ty) -> (Some v, cts c e.loc t)) vars ptys in
  let ret = cts c e.loc rty in
  let tok = W.method_def c.w c.cls (Printf.sprintf "prim%d" id) 0x0096
      { (static (List.filter (fun (t : S.t) -> t <> S.Void) (List.map snd params)) ret) with generic = List.length gvars } in
  List.iteri (fun (i : int) (_ : string) -> W.generic_param c.w tok i (Printf.sprintf "T%d" i)) gvars;
  (* (its name the method's, unique: partial's class is named after it) *)
  let f = { tok; fname = Printf.sprintf "prim%d" id; params; ptys; rty; cases = None; body; gvars } in
  let k' = new_code () in
  let i = ref 0 in
  List.iter
    (fun ((v, t) : Scope.var option * S.t) ->
      if t <> S.Void then begin
        (match v with Some v -> Hashtbl.replace k'.args v.vid !i | None -> ());
        incr i
      end)
    params;
  tail_expr c env k' body false;
  finish c k' tok;
  c.tvars <- outer;
  partial c env k e f []

(* a format as a value (Logs' m "...", a format given to a function):
 * fun k -> fun x1 -> ... fun xn -> k (sprintf "..." x1 ... xn), made
 * of synthetic expressions (Il_types.synthetic), compiled as any
 * closure; Format's (its 'b a Format.formatter) by Format.asprintf, its
 * @ directives text *)
and format_value (c : c) (env : env) (k : code) (e : Scope.expr) (s : string) : unit =
  let a, b, d = match unabbrev (type_of e) with Tconstr (_, [ a; b; _; d ]) -> (a, b, d) | _ -> refuse e.loc "a format" "3c" in
  let formatter = match b with Tconstr (bd, _) -> bd.tpath = "Format.formatter" | _ -> false in
  let pieces = Il_printf.parse e.loc formatter s in
  (* (the arguments: %a two, a printer and its value; the others one) *)
  let n = List.fold_left (fun n (p : Il_printf.piece) ->
      match p with Conv (_, 'a') -> n + 2 | Conv _ -> n + 1 | _ -> n) 0 pieces in
  let rec split (t : Scope.ty) (i : int) : Scope.ty list =
    if i = 0 then [] else match t with Tarrow (x, r) -> x :: split r (i - 1) | _ -> refuse e.loc "a format's arguments" "3c" in
  let ptys = split a n in
  incr format_values;
  let id = !format_values in
  let count = ref 0 in
  let fresh (t : Scope.ty) (x : Scope.exp) : Scope.expr =
    incr count;
    let ex : Scope.expr = { e = x; loc = e.loc; span = (- !count, - 1000000 - id) } in
    Hashtbl.replace synthetic ex.span t;
    ex in
  let var (name : string) (t : Scope.ty) : Scope.var =
    incr count;
    let v : Scope.var = { vname = name; vid = - 2000000000 - 1000 * id - !count } in
    Hashtbl.replace synthetic_vars v.vid t;
    v in
  let kty = Scope.Tarrow (Resolve.string_t, d) in
  let kv = var "k" kty in
  let xs = List.mapi (fun (i : int) (t : Scope.ty) -> var (Printf.sprintf "x%d" i) t) ptys in
  let global (sym : string) : Scope.global =
    { gpath = [ String.sub sym 0 (String.index sym '.') ]; gname = sym; gsym = sym; gtype = None; glabels = [] } in
  let arrows (ts : Scope.ty list) (r : Scope.ty) = List.fold_right (fun (t : Scope.ty) (r : Scope.ty) -> Scope.Tarrow (t, r)) ts r in
  (* (%a's and %t's text, the printer's captured: Format's on a buffer's
   * formatter, sprintf's its string, bprintf's a buffer's) *)
  let capture (t : bool) (args : (Scope.var * Scope.ty) list) : Scope.expr =
    let fn = match b with
      | Tconstr (bd, _) when bd.tpath = "Format.formatter" -> "Format_dotnet.capture"
      | Tconstr (bd, _) when bd.tpath = "unit" -> "Printf_dotnet.capture"
      | Tconstr (bd, _) when bd.tpath = "Buffer.t" -> "Printf_dotnet.capture_buffer"
      | _ -> refuse e.loc "%a or %t in a format of a channel's (fprintf's: its text cannot be taken)" "3c" in
    let fn = if t then fn ^ "_t" else fn in
    fresh Resolve.string_t
      (Eapply (fresh (arrows (List.map snd args) Resolve.string_t) (Evar (Global (global fn))),
               List.map (fun ((v, ty) : Scope.var * Scope.ty) -> fresh ty (Evar (Local v))) args)) in
  (* the format again, %a and %t now %s, a text the sprintf's own
   * (Format's directives done: escaped %, no @ read again) *)
  let rest = ref (List.combine xs ptys) in
  let take () = match !rest with x :: r -> rest := r; x | [] -> refuse e.loc "a format's arguments" "3c" in
  let args = ref [] in
  let fmt = String.concat "" (List.map (fun (p : Il_printf.piece) ->
      match p with
      | Text t -> String.concat "%%" (String.split_on_char '%' t)
      | Flush -> ""
      | Conv (_, 'a') -> let pr = take () in let x = take () in args := capture false [ pr; x ] :: !args; "%s"
      | Conv (_, 't') -> let pr = take () in args := capture true [ pr ] :: !args; "%s"
      | Conv (spec, _) -> let (v, t) = take () in args := fresh t (Evar (Local v)) :: !args; spec) pieces) in
  let args = List.rev !args in
  let fn_ty = arrows (Resolve.string_t :: List.map type_of args) Resolve.string_t in
  let text =
    fresh Resolve.string_t
      (Eapply (fresh fn_ty (Evar (Global (global "Printf.sprintf"))), fresh Resolve.string_t (Econst (String fmt)) :: args)) in
  let body = fresh d (Eapply (fresh kty (Evar (Local kv)), [ text ])) in
  let inner =
    List.fold_right2
      (fun (v : Scope.var) (t : Scope.ty) (b : Scope.expr) -> fresh (Scope.Tarrow (t, type_of b)) (Efunction [ (Pvar v, None, b) ]))
      xs ptys body in
  let outer = fresh (Scope.Tarrow (kty, a)) (Efunction [ (Pvar kv, None, inner) ]) in
  lambda c env k outer None []

(* the record the primitives' compiler is given *)
and compiler (c : c) (env : env) (k : code) : Il_prims.compiler =
  { Il_prims.expr = expr c env k; operands = operands c env k; values = values c env k; drop = drop c env k }
