(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Il_prims.mli *)

module S = Signature
module W = Writer
open Il_code
open Il_types
open Il_functions

(* the expressions' compiler (Il_exprs'), which the primitives' operands
 * are given to *)
type compiler = {
  expr : Scope.expr -> unit;
  operands : Scope.expr list -> unit;
  values : Scope.expr list -> unit;
  drop : Scope.expr -> unit;
}

(* a call of the runtime unit's function of a C primitive's name, all
 * its arguments given, it not polymorphic: each argument converted to
 * its parameter's type, which may be another than the external's (the
 * primitive of output_char is output_byte's, an int there), the result
 * back; sys_exit's 'a, which no value reaches, a default one. false
 * when it is not so (a partial application: call's) *)
let rec runtime_call (c : c) (k : code) (cx : compiler) (e : Scope.expr) (f : fn) (args : Scope.expr list) : bool =
  if f.gvars <> [] || List.length args <> List.length f.params then false
  else begin
    let saved = k.pending in
    List.iter2
      (fun (a : Scope.expr) ((_, t) : Scope.var option * S.t) ->
        cx.expr a;
        if t <> S.Void then begin
          Il_externals.convert c k (cts_of c a) t;
          k.pending <- k.pending + 1
        end)
      args f.params;
    k.pending <- saved;
    emit k (Il.Call f.tok);
    let ret = if raises_always f then S.Void else cts c e.loc f.rty in
    (match ret, cts_of c e with
     | S.Void, t -> default k t
     | _, S.Void -> emit k Il.Pop
     | r, t -> Il_externals.convert c k r t);
    true
  end

(* a value of a type where a call returned none (a function that always
 * raises, invalid_arg, its method's result void; sys_exit): never
 * reached, but the stack typed as the caller's *)
and default (k : code) (t : S.t) : unit =
  match t with
  | S.Void -> ()
  | S.I8 -> emit k (Il.Ldc_i8 0L)
  | S.I4 | S.Bool | S.Char | S.U1 -> emit k (Il.Ldc_i4 0l)
  | S.R8 -> emit k (Il.Ldc_r 0.0)
  | _ -> emit k Il.Ldnull

(* a call of an external naming a .NET member (decision 7): its
 * arguments converted to its parameters' .NET types, its result back *)
and dotnet (c : c) (k : code) (cx : compiler) (e : Scope.expr) (p : string) (pty : Scope.ty) (args : Scope.expr list) : unit =
  let m = Il_externals.member c e.loc p pty in
  let n = List.length (fst (Il_externals.arrows pty)) in
  if List.length args <> n then refuse e.loc (p ^ ", an external given fewer or more arguments than its type's") "3b";
  let saved = k.pending in
  let pending = ref (List.combine m.from m.into) in
  (* (a this of a value type, a double's ToString: its address, and a
   * call, not a callvirt) *)
  let by_address = not m.static && (match m.into with t :: _ -> Il_externals.is_value t | [] -> false) in
  List.iteri
    (fun (i : int) (a : Scope.expr) ->
      cx.expr a;
      if cts_of c a <> S.Void then begin
        (match !pending with
         | (f, t) :: rest -> Il_externals.convert c k f t; pending := rest
         | [] -> ());
        if i = 0 && by_address then begin
          let v = local k (List.hd m.into) in
          emit k (Il.Stloc v);
          emit k (Il.Ldloca v)
        end;
        k.pending <- k.pending + 1
      end)
    args;
  k.pending <- saved;
  emit k (if m.static || by_address then Il.Call m.tok else Il.Callvirt m.tok);
  if m.ml_ret = S.Void && m.ret <> S.Void then emit k Il.Pop
  else Il_externals.convert c k m.ret m.ml_ret

and prim (c : c) (env : env) (k : code) (cx : compiler) (e : Scope.expr) (p : string) (args : Scope.expr list) : unit =
  (* (Pervasives' string_length and bytes_length: the native compiler's
   * builtin, of either type, as %string_length is) *)
  let p = if p = "ml_string_length" then "%string_length" else p in
  let all () = cx.operands args in
  let op (o : Il.op) = all (); emit k o in
  let first () : S.t = match args with a :: _ -> cts_of c a | [] -> S.Void in
  (* both operands boxed (a type variable's value) *)
  let boxed () =
    let ty = first () in
    match args with
    | [ a; b ] ->
        cx.expr a; emit k (Il.Box (W.type_spec c.w ty));
        k.pending <- k.pending + 1; cx.expr b; emit k (Il.Box (W.type_spec c.w ty)); k.pending <- k.pending - 1
    | _ -> refuse e.loc "a comparison of a polymorphic value" "1d" in
  (* (bytes compared, = too, by their contents: as strings, the runtime
   * unit's copies) *)
  let as_strings () =
    let sob = match Hashtbl.find_opt env.by_sym "Runtime.string_of_bytes" with
      | Some f -> f.tok | None -> refuse e.loc "bytes compared, without the runtime unit" "3b" in
    match args with
    | [ a; b ] ->
        cx.expr a; emit k (Il.Call sob);
        k.pending <- k.pending + 1; cx.expr b; emit k (Il.Call sob); k.pending <- k.pending - 1
    | _ -> refuse e.loc "bytes compared" "1d" in
  (* a comparison: a string's by CompareOrdinal against 0; a type
   * variable's by the assembly's Ml::compare *)
  let compare (lt : bool) (negate : bool) =
    (match first () with
    | S.SzArray S.U1 ->
        as_strings ();
        emit k (Il.Call (lib c "String" "CompareOrdinal" (static [ S.String; S.String ] S.I4)));
        emit k (Il.Ldc_i4 0l)
    | S.String ->
        all ();
        emit k (Il.Call (lib c "String" "CompareOrdinal" (static [ S.String; S.String ] S.I4)));
        emit k (Il.Ldc_i4 0l)
    | S.MVar _ | S.Var _ ->
        boxed ();
        emit k (Il.Call (ml_compare c));
        emit k (Il.Ldc_i4 0l)
    (* (a record's, a variant's: their structural CompareTo, by it) *)
    | S.Class _ | S.GenericInst _ ->
        all ();
        emit k (Il.Call (ml_compare c));
        emit k (Il.Ldc_i4 0l)
    | _ -> all ());
    (* (a float's NaN: unordered, so a <= b is not (a > b, or unordered)) *)
    let unordered = negate && first () = S.R8 in
    emit k (if lt then Il.Clt unordered else Il.Cgt unordered);
    if negate then (emit k (Il.Ldc_i4 0l); emit k Il.Ceq) in
  let equal () =
    match first () with
    | S.String -> op (Il.Call (lib c "String" "op_Equality" (static [ S.String; S.String ] S.Bool)))
    | S.SzArray S.U1 when p = "%equal" || p = "%notequal" ->
        as_strings (); emit k (Il.Call (lib c "String" "op_Equality" (static [ S.String; S.String ] S.Bool)))
    (* (a polymorphic function's value: boxed, its own Equals, an int's
     * or a record's) *)
    | (S.MVar _ | S.Var _) as t when p = "%equal" || p = "%notequal" ->
        let box () = emit k (Il.Box (W.type_spec c.w t)) in
        (match args with
         | [ a; b ] ->
             cx.expr a; box ();
             k.pending <- k.pending + 1; cx.expr b; box (); k.pending <- k.pending - 1;
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
      cx.expr a;
      emit k (Il.Brfalse no);
      cx.expr b;
      emit k (Il.Br over);
      place k no;
      emit k (Il.Ldc_i4 0l);
      place k over
  | "%sequor", [ a; b ] ->
      let yes = label k and over = label k in
      cx.expr a;
      emit k (Il.Brtrue yes);
      cx.expr b;
      emit k (Il.Br over);
      place k yes;
      emit k (Il.Ldc_i4 1l);
      place k over
  | "%string_length", [ s ] when cts_of c s = S.SzArray S.U1 -> all (); emit k Il.Ldlen; emit k (Il.Conv (Il.K_i8, false, false))
  | "%string_length", _ -> all (); emit k (Il.Callvirt (lib c "String" "get_Length" (instance [] S.I4))); emit k (Il.Conv (Il.K_i8, false, false))
  (* (bytes: a byte[]'s element, a uint8, our char an int32) *)
  | ("%string_safe_get" | "%string_unsafe_get"), [ s; i ] when cts_of c s = S.SzArray S.U1 ->
      cx.expr s;
      k.pending <- k.pending + 1; cx.expr i; k.pending <- k.pending - 1;
      emit k (Il.Conv (Il.K_i4, false, false));
      emit k (Il.Ldelem Il.K_u1)
  (* (a byte[] made, IL's newarr: the runtime unit's create_string) *)
  | "%bytes_create", _ -> all (); emit k (Il.Conv (Il.K_i4, false, false)); emit k (Il.Newarr (sys c "Byte"))
  (* (little-endian 16 and 32 bits at an index of a string or bytes:
   * their bytes, read or written one by one) *)
  | ("%caml_bytes_get16" | "%caml_bytes_get32"), [ s; i ] ->
      let n = if p = "%caml_bytes_get16" then 2 else 4 in
      let st = cts_of c s in
      let sv = local k st and iv = local k S.I4 in
      cx.expr s; emit k (Il.Stloc sv);
      cx.expr i; emit k (Il.Conv (Il.K_i4, false, false)); emit k (Il.Stloc iv);
      for j = 0 to n - 1 do
        emit k (Il.Ldloc sv); emit k (Il.Ldloc iv); emit k (Il.Ldc_i4 (Int32.of_int j)); emit k (Il.Binop Il.Add);
        if st = S.String then emit k (Il.Callvirt (lib c "String" "get_Chars" (instance [ S.I4 ] S.Char)))
        else emit k (Il.Ldelem Il.K_u1);
        if j > 0 then (emit k (Il.Ldc_i4 (Int32.of_int (8 * j))); emit k (Il.Binop Il.Shl); emit k (Il.Binop Il.Or))
      done;
      if n = 2 then emit k (Il.Conv (Il.K_i8, false, false))
  | ("%caml_bytes_set16" | "%caml_bytes_set32"), [ b; i; x ] ->
      let n = if p = "%caml_bytes_set16" then 2 else 4 in
      let bv = local k (S.SzArray S.U1) and iv = local k S.I4 and xv = local k S.I4 in
      cx.expr b; emit k (Il.Stloc bv);
      cx.expr i; emit k (Il.Conv (Il.K_i4, false, false)); emit k (Il.Stloc iv);
      cx.expr x; emit k (Il.Conv (Il.K_i4, false, false)); emit k (Il.Stloc xv);
      for j = 0 to n - 1 do
        emit k (Il.Ldloc bv); emit k (Il.Ldloc iv); emit k (Il.Ldc_i4 (Int32.of_int j)); emit k (Il.Binop Il.Add);
        emit k (Il.Ldloc xv); emit k (Il.Ldc_i4 (Int32.of_int (8 * j))); emit k (Il.Binop Il.Shr);
        emit k (Il.Stelem Il.K_i1)
      done
  (* (Hashtbl.hash's: Ml::hash of the value boxed, the runtime unit's
   * hash_univ_param) *)
  | "%hash", [ a ] ->
      cx.expr a;
      (match cts_of c a with
       | S.I8 -> emit k (Il.Box (sys c "Int64"))
       | S.R8 -> emit k (Il.Box (sys c "Double"))
       | S.I4 -> emit k (Il.Box (sys c "Int32"))
       | S.Bool -> emit k (Il.Box (sys c "Boolean"))
       | (S.Var _ | S.MVar _) as t -> emit k (Il.Box (W.type_spec c.w t))
       | _ -> ());
      emit k (Il.Call (ml_hash c));
      emit k (Il.Conv (Il.K_i8, false, false))
  (* (Sys's: .NET's int an int64, its word 64 bits) *)
  | ("%word_size" | "%int_size"), _ -> all (); emit k (Il.Ldc_i8 64L)
  (* (a T[] of n nulls or zeros: the runtime unit's make_vect) *)
  | "%array_create", _ ->
      let tok = match cts_of c e with S.SzArray t -> type_token c t | _ -> refuse e.loc "an array" "1d" in
      all (); emit k (Il.Conv (Il.K_i4, false, false)); emit k (Il.Newarr tok)
  | ("%string_safe_set" | "%string_unsafe_set"), [ s; i; x ] when cts_of c s = S.SzArray S.U1 ->
      cx.expr s;
      k.pending <- k.pending + 1; cx.expr i; emit k (Il.Conv (Il.K_i4, false, false));
      k.pending <- k.pending + 1; cx.expr x;
      k.pending <- k.pending - 2;
      emit k (Il.Stelem Il.K_i1)
  (* (s.[i]: String's Chars, a UTF-16 unit, a byte here: our char) *)
  | ("%string_safe_get" | "%string_unsafe_get"), [ s; i ] ->
      cx.expr s;
      k.pending <- k.pending + 1;
      cx.expr i;
      k.pending <- k.pending - 1;
      emit k (Il.Conv (Il.K_i4, false, false));
      emit k (Il.Callvirt (lib c "String" "get_Chars" (instance [ S.I4 ] S.Char)));
      emit k (Il.Conv (Il.K_i4, false, false))
  (* ref, !, :=, incr, decr: Pervasives' 'a ref, a record *)
  | "%makemutable", _ -> cx.values args; emit k (Il.Newobj (record_ctor c e.loc (type_of e)))
  | "%field0", [ r ] ->
      cx.expr r;
      emit k (Il.Ldfld (field0 c e.loc (type_of r)));
      if cts_of c e = S.Void then emit k Il.Pop
  | "%setfield0", [ r; _ ] -> cx.values args; emit k (Il.Stfld (field0 c e.loc (type_of r)))
  | ("%incr" | "%decr"), [ r ] ->
      let f = field0 c e.loc (type_of r) in
      cx.expr r;
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
                    cx.expr a; List.iter (emit k) box;
                    k.pending <- k.pending + 1; cx.expr b; List.iter (emit k) box; k.pending <- k.pending - 1
                | _ -> ()));
          emit k (Il.Call (ml_compare c));
          emit k (Il.Conv (Il.K_i8, false, false))
      | S.Class _ | S.GenericInst _ -> all (); emit k (Il.Call (ml_compare c)); emit k (Il.Conv (Il.K_i8, false, false))
      | S.SzArray S.U1 -> as_strings (); emit k (Il.Call (ml_compare c)); emit k (Il.Conv (Il.K_i8, false, false))
      | _ -> refuse e.loc "compare of a value of no order (a function, an array)" "1d")
  (* an array's length, an element read and written (an index an
   * int32: IL's) *)
  | "%array_length", _ -> all (); emit k Il.Ldlen; emit k (Il.Conv (Il.K_i8, false, false))
  | ("%array_safe_get" | "%array_unsafe_get"), [ a; i ] ->
      let tok = match cts_of c a with S.SzArray t -> type_token c t | _ -> refuse e.loc "an array" "1d" in
      cx.expr a;
      k.pending <- k.pending + 1; cx.expr i; k.pending <- k.pending - 1;
      emit k (Il.Conv (Il.K_i4, false, false));
      emit k (Il.Ldelem_any tok);
      if cts_of c e = S.Void then emit k Il.Pop
  | ("%array_safe_set" | "%array_unsafe_set"), [ a; i; x ] ->
      let tok = match cts_of c a with S.SzArray t -> type_token c t | _ -> refuse e.loc "an array" "1d" in
      cx.expr a;
      k.pending <- k.pending + 1; cx.expr i; emit k (Il.Conv (Il.K_i4, false, false));
      k.pending <- k.pending + 1; cx.expr x; if cts_of c x = S.Void then emit k Il.Ldnull;
      k.pending <- k.pending - 2;
      emit k (Il.Stelem_any tok)
  (* (bytes a string and back, Bytes.to_string's: a copy, by the
   * runtime unit's functions, .NET's string being another object) *)
  | "%identity", [ a ] when (match cts_of c a, cts_of c e with S.SzArray S.U1, S.String | S.String, S.SzArray S.U1 -> true | _ -> false) ->
      let name = if cts_of c a = S.String then "Runtime.bytes_of_string" else "Runtime.string_of_bytes" in
      (match Hashtbl.find_opt env.by_sym name with
       | Some f -> all (); emit k (Il.Call f.tok)
       | None -> refuse e.loc ("bytes and strings, without the runtime unit's " ^ name) "3b")
  (* (an int a char and back, Char.code's: int64 and int32; an abstract
   * type's object the class it is) *)
  | "%identity", [ a ] ->
      all ();
      (* (Obj.repr (): unit's nothing an object's null, and back) *)
      (match cts_of c a, cts_of c e with
       | S.Void, t -> default k t
       | _, S.Void -> emit k Il.Pop
       | f, t -> Il_externals.convert c k f t)
  | "%ignore", [ a ] -> cx.drop a
  | "%raise", [ a ] -> cx.expr a; emit k Il.Throw
  (* (a primitive of the native runtime's C: the library's) *)
  | _ when String.length p > 0 && p.[0] <> '%' -> refuse e.loc ("the primitive " ^ p ^ ", not in the runtime unit (lib_core/dotnet/Runtime.ml)") "3b"
  | _ -> refuse e.loc ("the primitive " ^ p) "1a"
