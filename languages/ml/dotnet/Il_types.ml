(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Il_types.mli *)

module S = Signature
module W = Writer
open Il_code

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

(* structural equality, F#'s: Equals of an object of the same class
 * whose fields are equal (an int's, a float's, a string's text, an ML
 * value's own Equals), and GetHashCode of the fields', so that = is a
 * call of Equals, and a .NET set or dictionary holds ML values as
 * OCaml's = sees them *)
let structural (c : c) (cls : int) (tag : int) (fields : (int * S.t) list) : unit =
  let eq = W.method_def c.w cls "Equals" 0x00C6 (instance [ S.Object ] S.Bool) in
  let k = new_code () in
  let o = local k (S.Class cls) and no = label k in
  emit k (Il.Ldarg 1);
  emit k (Il.Isinst cls);
  emit k (Il.Stloc o);
  emit k (Il.Ldloc o);
  emit k (Il.Brfalse no);
  List.iter
    (fun ((f, t) : int * S.t) ->
      emit k (Il.Ldarg 0);
      emit k (Il.Ldfld f);
      emit k (Il.Ldloc o);
      emit k (Il.Ldfld f);
      (match t with
       | S.String -> emit k (Il.Call (lib c "String" "op_Equality" (static [ S.String; S.String ] S.Bool)))
       | S.Class _ -> emit k (Il.Callvirt (lib c "Object" "Equals" (instance [ S.Object ] S.Bool)))
       | _ -> emit k Il.Ceq);
      emit k (Il.Brfalse no))
    fields;
  emit k (Il.Ldc_i4 1l);
  emit k Il.Ret;
  place k no;
  emit k (Il.Ldc_i4 0l);
  emit k Il.Ret;
  finish c k eq;
  let hash = W.method_def c.w cls "GetHashCode" 0x00C6 (instance [] S.I4) in
  let k = new_code () in
  emit k (Il.Ldc_i4 (Int32.of_int tag));
  List.iter
    (fun ((f, t) : int * S.t) ->
      emit k (Il.Ldc_i4 31l);
      emit k (Il.Binop Il.Mul);
      emit k (Il.Ldarg 0);
      emit k (Il.Ldfld f);
      (match t with
       | S.I8 ->
           (* (its two halves mixed) *)
           emit k Il.Dup;
           emit k (Il.Ldc_i4 32l);
           emit k (Il.Binop Il.Shr);
           emit k (Il.Binop Il.Xor);
           emit k (Il.Conv (Il.K_i4, false, false))
       | S.R8 -> emit k (Il.Box (sys c "Double")); emit k (Il.Callvirt (lib c "Object" "GetHashCode" (instance [] S.I4)))
       | S.String | S.Class _ -> emit k (Il.Callvirt (lib c "Object" "GetHashCode" (instance [] S.I4)))
       | _ -> ());
      emit k (Il.Binop Il.Add))
    fields;
  emit k Il.Ret;
  finish c k hash

let decl (t : Scope.ty) : Scope.tdecl = match t with Tconstr (d, _) -> d | _ -> assert false
let int_d = decl Resolve.int_t and bool_d = decl Resolve.bool_t and unit_d = decl Resolve.unit_t
let char_d = decl Resolve.char_t and float_d = decl Resolve.float_t and string_d = decl Resolve.string_t
let exn_d = decl Resolve.exn_t

(* a type's namespace and name: a path's own, else the unit's *)
let split (c : c) (path : string) : string * string =
  match String.rindex_opt path '.' with
  | Some i -> (String.sub path 0 i, String.sub path (i + 1) (String.length path - i - 1))
  | None -> (c.uname, path)

(* a type of the unit: a class nested in the unit's (F#'s modules: so
 * C# names it Unit.t, and no namespace has the unit's class's name);
 * [flags] its own, NestedPublic added; another unit's, not yet *)
let nested (c : c) (loc : int) (path : string) (flags : int) (parent : int) : int =
  let ns, name = split c path in
  if ns <> c.uname then refuse loc ("the type " ^ path ^ ", of another unit") "1e";
  let cls = W.type_def c.w "" name (flags lor 0x2) parent in
  W.nest c.w cls c.cls;
  cls

(* an ML type's .NET type; unit's Void (no value) *)
let rec cts (c : c) (loc : int) (t : Scope.ty) : S.t =
  match t with
  | Tconstr (d, []) when d == int_d -> S.I8
  | Tconstr (d, []) when d == bool_d -> S.Bool
  | Tconstr (d, []) when d == char_d -> S.I4
  | Tconstr (d, []) when d == float_d -> S.R8
  | Tconstr (d, []) when d == string_d -> S.String
  | Tconstr (d, []) when d == unit_d -> S.Void
  | Tconstr (d, []) when d == exn_d -> S.Class (sys c "Exception")
  | Tconstr ({ tabbrev = Some t; _ }, []) -> cts c loc t
  | Tconstr (d, []) when Resolve.type_fields d <> None -> S.Class (record c loc d)
  | Tconstr (d, []) when Resolve.type_conses d <> None -> S.Class (variant c loc d)
  | Tvar _ -> refuse loc "a polymorphic value" "1d"
  | Tarrow (a, b) -> func c loc a b
  | Ttuple _ -> refuse loc "a tuple" "1d"
  | Tconstr (d, _ :: _) -> refuse loc ("a value of type " ^ d.tpath ^ ", of parameters") "1d"
  | Tconstr (d, []) -> refuse loc ("a value of type " ^ d.tpath) "1b"

(* a type as a Func's argument or result: unit an object, always null
 * (F#'s unit: .NET has no void type argument) *)
and arg_type (c : c) (loc : int) (t : Scope.ty) : S.t = match cts c loc t with S.Void -> S.Object | t -> t

(* a function, System.Func<A, B>: curried as ML's, int -> int -> int a
 * Func<long, Func<long, long>> *)
and func (c : c) (loc : int) (a : Scope.ty) (b : Scope.ty) : S.t =
  S.GenericInst (S.Class (sys c "Func`2"), [ arg_type c loc a; arg_type c loc b ])

(* a record type: a class of its fields, in their order *)
and record (c : c) (loc : int) (d : Scope.tdecl) : int =
  let key = "record " ^ d.tpath in
  match Hashtbl.find_opt c.memo key with
  | Some cls -> cls
  | None ->
      let labels = match Resolve.type_fields d with Some l -> l | None -> [] in
      let labels = List.sort (fun ((_, a) : string * Scope.label) ((_, b) : string * Scope.label) -> compare a.pos b.pos) labels in
      (* (made before its fields' types, which may be its own: a type
       * of the metadata is its token, known at once) *)
      let cls = nested c loc d.tpath 0x00100000 (sys c "Object") in
      Hashtbl.replace c.memo key cls;
      let fields = List.map (fun ((n, l) : string * Scope.label) -> let _, ty, _ = l.ltype in (n, cts c loc ty)) labels in
      let toks = List.map (fun ((n, t) : string * S.t) -> W.field_def c.w cls n 0x0006 t) fields in
      List.iter2 (fun ((n, _) : string * S.t) (f : int) -> Hashtbl.replace c.memo (key ^ "." ^ n) f) fields toks;
      let ctor = W.method_def c.w cls ".ctor" 0x1886 (instance (List.map snd fields) S.Void) in
      let sets = List.concat (List.mapi (fun (i : int) (f : int) -> [ Il.Ldarg 0; Il.Ldarg (i + 1); Il.Stfld f ]) toks) in
      W.set_body c.w ctor [] (Array.of_list ([ Il.Ldarg 0; Il.Call (object_ctor c) ] @ sets @ [ Il.Ret ])) [];
      Hashtbl.replace c.memo ("ctor " ^ key) ctor;
      structural c cls 0 (List.combine toks (List.map snd fields));
      cls

(* a variant type: an abstract class, and a class of each constructor's,
 * nested in it, its fields the constructor's arguments (Item1...) *)
and variant (c : c) (loc : int) (d : Scope.tdecl) : int =
  let key = "variant " ^ d.tpath in
  match Hashtbl.find_opt c.memo key with
  | Some cls -> cls
  | None ->
      let cls = nested c loc d.tpath 0x00100080 (sys c "Object") in
      Hashtbl.replace c.memo key cls;
      let ctor = W.method_def c.w cls ".ctor" 0x1886 (instance [] S.Void) in
      W.set_body c.w ctor [] [| Il.Ldarg 0; Il.Call (object_ctor c); Il.Ret |] [];
      List.iteri
        (fun (tag : int) ((cname, k) : string * Scope.cons) ->
          if k.cinline <> [] then refuse loc (cname ^ ", a constructor of an inline record") "1b";
          let _, args, _ = k.ctype in
          let fields = List.mapi (fun (i : int) (t : Scope.ty) -> (Printf.sprintf "Item%d" (i + 1), cts c loc t)) args in
          let case, case_ctor, toks = new_class c "" cname 0x00100102 cls ctor [] fields in
          W.nest c.w case cls;
          structural c case tag (List.combine toks (List.map snd fields));
          Hashtbl.replace c.memo (key ^ "|" ^ cname) case;
          Hashtbl.replace c.memo (key ^ "|" ^ cname ^ " ctor") case_ctor;
          List.iteri (fun (i : int) (f : int) -> Hashtbl.replace c.memo (Printf.sprintf "%s|%s.%d" key cname i) f) toks)
        (match Resolve.type_conses d with Some l -> l | None -> []);
      cls

let field (c : c) (loc : int) (d : Scope.tdecl) (name : string) : int =
  ignore (record c loc d);
  Hashtbl.find c.memo ("record " ^ d.tpath ^ "." ^ name)

let record_ctor (c : c) (loc : int) (d : Scope.tdecl) : int =
  ignore (record c loc d);
  Hashtbl.find c.memo ("ctor record " ^ d.tpath)

(* a constructor of a variant: its class, constructor, fields *)
let case (c : c) (loc : int) (k : Scope.cons) : int * int * (int -> int) =
  let _, _, res = k.ctype in
  let d = decl res in
  ignore (variant c loc d);
  let key = "variant " ^ d.tpath ^ "|" ^ k.cname in
  (Hashtbl.find c.memo key, Hashtbl.find c.memo (key ^ " ctor"), fun (i : int) -> Hashtbl.find c.memo (Printf.sprintf "%s.%d" key i))

(* an exception: a class of System.Exception's, its message its name;
 * OCaml's Division_by_zero .NET's own, which a division throws *)
let exn (c : c) (loc : int) (sym : string) (args : Scope.ty list) : int * int * (int -> int) =
  if sym = "caml_exn_Division_by_zero" then
    (sys c "DivideByZeroException", lib c "DivideByZeroException" ".ctor" (instance [] S.Void), fun (_ : int) -> 0)
  else begin
    let key = "exn " ^ sym in
    let name =
      if String.length sym > 9 && String.sub sym 0 9 = "caml_exn_" then String.sub sym 9 (String.length sym - 9)
      else snd (split c sym) in
    let predefined = String.length sym > 9 && String.sub sym 0 9 = "caml_exn_" in
    if not (Hashtbl.mem c.memo key) then begin
      let fields = List.mapi (fun (i : int) (t : Scope.ty) -> (Printf.sprintf "Item%d" (i + 1), cts c loc t)) args in
      let base = lib c "Exception" ".ctor" (instance [ S.String ] S.Void) in
      (* (OCaml's own, Failure, Not_found...: Stdlib's; the unit's
       * nested in its class) *)
      if not predefined && fst (split c sym) <> c.uname then refuse loc ("the exception " ^ sym ^ ", of another unit") "1e";
      let cls, ctor, toks =
        new_class c (if predefined then "Stdlib" else "") name (if predefined then 0x00100001 else 0x00100002) (sys c "Exception") base
          [ Il.Ldstr (W.user_string c.w name) ] fields in
      if not predefined then W.nest c.w cls c.cls;
      Hashtbl.replace c.memo key cls;
      Hashtbl.replace c.memo (key ^ " ctor") ctor;
      List.iteri (fun (i : int) (f : int) -> Hashtbl.replace c.memo (Printf.sprintf "%s.%d" key i) f) toks
    end;
    (Hashtbl.find c.memo key, Hashtbl.find c.memo (key ^ " ctor"), fun (i : int) -> Hashtbl.find c.memo (Printf.sprintf "%s.%d" key i))
  end

let type_of (e : Scope.expr) : Scope.ty =
  match Typing.expr_type e.span with Some t -> t | None -> refuse e.loc "an expression whose type was not kept" "1a"

(* (a raise's type is any: nothing is left by it) *)
let is_raise (e : Scope.expr) : bool =
  match e.e with Eapply ({ e = Evar (Prim ("%raise", _, _)); _ }, _) -> true | _ -> false

let cts_of (c : c) (e : Scope.expr) : S.t = if is_raise e then S.Void else cts c e.loc (type_of e)

(* a Func's Invoke and constructor (an object, a method's address) *)
let invoke (c : c) (f : S.t) : int =
  memo c ("invoke " ^ S.encode_type_spec f) (fun () -> W.member_ref c.w (W.type_spec c.w f) "Invoke" (instance [ S.Var 0 ] (S.Var 1)))

let func_ctor (c : c) (f : S.t) : int =
  memo c ("func ctor " ^ S.encode_type_spec f) (fun () ->
      W.member_ref c.w (W.type_spec c.w f) ".ctor" (instance [ S.Object; S.I ] S.Void))
