(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Il_patterns.mli *)

module S = Signature
module W = Writer
open Il_code
open Il_types

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
      let cls, _, fld, args =
        match k'.kind with
        | Exn g -> let cls, ctor, fld = exn c 0 g.gsym args in (cls, ctor, fld, args)
        | Const _ | Block _ -> case c 0 k' ty in
      load ();
      emit k (Il.Isinst cls);
      emit k (Il.Brfalse fail);
      List.iteri
        (fun (i : int) ((p, t) : Scope.pattern * Scope.ty) ->
          pattern c k (fun () -> load (); emit k (Il.Castclass cls); emit k (Il.Ldfld (fld i))) t p fail)
        (List.combine ps args)
  | Precord fs ->
      List.iter
        (fun ((l, p) : Scope.label * Scope.pattern) ->
          pattern c k (fun () -> load (); emit k (Il.Ldfld (field c 0 ty l.lname))) (label_type l ty) p fail)
        fs
  | Por (a, b) ->
      let other = label k and ok = label k in
      pattern c k load ty a other;
      emit k (Il.Br ok);
      place k other;
      pattern c k load ty b fail;
      place k ok
  | Ptuple ps ->
      let ts = match ty with Ttuple ts -> ts | _ -> refuse 0 "a tuple pattern of no tuple type" "1d" in
      List.iteri
        (fun (i : int) ((p, t) : Scope.pattern * Scope.ty) ->
          pattern c k (fun () -> load (); emit k (Il.Ldfld (tuple_field c 0 ty i))) t p fail)
        (List.combine ps ts)
