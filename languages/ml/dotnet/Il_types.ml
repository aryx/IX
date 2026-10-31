(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Il_types.mli *)

module S = Signature
module W = Writer
open Il_code

(*****************************************************************************)
(* A type's class *)
(*****************************************************************************)

(* a class made for a type (a record, a variant, a variant's
 * constructor): its TypeDef, its generic parameters' number, its
 * fields' names and types as declared (in its own parameters, !0...),
 * their FieldDefs, its constructor (the fields in order) *)
type tclass = {
  tok : int;
  arity : int;
  mutable fields : (string * S.t) list;
  mutable ftoks : int list;
  mutable ctor : int;
}

(* the unit's, by type (path) and by constructor (path|name) *)
let classes : (string, tclass) Hashtbl.t = Hashtbl.create 16

let reset () : unit = Hashtbl.reset classes

(* a class's own parameters, !0..., as its methods see them *)
let own (t : tclass) : S.t list = List.init t.arity (fun (i : int) -> S.Var i)

(* the class at type arguments: itself, or its instance *)
let at (t : tclass) (args : S.t list) : S.t = if t.arity = 0 then S.Class t.tok else S.GenericInst (S.Class t.tok, args)

(* its token for isinst, castclass, a parent: the TypeDef, or the
 * instance's TypeSpec *)
let type_tok (c : c) (t : tclass) (args : S.t list) : int = if t.arity = 0 then t.tok else W.type_spec c.w (at t args)

(* its i-th field at type arguments: the FieldDef, or a MemberRef on the
 * instance (C#'s, and what a generic class's own methods use) *)
let field_tok (c : c) (t : tclass) (args : S.t list) (i : int) : int =
  if t.arity = 0 then List.nth t.ftoks i
  else
    let name, ty = List.nth t.fields i in
    memo c ("field " ^ S.encode_type_spec (at t args) ^ "." ^ name) (fun () -> W.field_ref c.w (W.type_spec c.w (at t args)) name ty)

let ctor_tok (c : c) (t : tclass) (args : S.t list) : int =
  if t.arity = 0 then t.ctor
  else
    memo c ("ctor " ^ S.encode_type_spec (at t args)) (fun () ->
        W.member_ref c.w (W.type_spec c.w (at t args)) ".ctor" (instance (List.map snd t.fields) S.Void))

(* structural equality, F#'s: Equals of an object of the same class
 * whose fields are equal (an int's, a float's, a string's text, an ML
 * value's own Equals, a type parameter's boxed), and GetHashCode of the
 * fields', so that = is a call of Equals, and a .NET set or dictionary
 * holds ML values as OCaml's = sees them *)
let structural (c : c) (t : tclass) (tag : int) : unit =
  let me = own t in
  let fields = List.mapi (fun (i : int) ((_, ty) : string * S.t) -> (field_tok c t me i, ty)) t.fields in
  let box (ty : S.t) (k : code) = match ty with S.Var _ -> emit k (Il.Box (W.type_spec c.w ty)) | _ -> () in
  let eq = W.method_def c.w t.tok "Equals" 0x00C6 (instance [ S.Object ] S.Bool) in
  let k = new_code () in
  let o = local k (at t me) and no = label k in
  emit k (Il.Ldarg 1);
  emit k (Il.Isinst (type_tok c t me));
  emit k (Il.Stloc o);
  emit k (Il.Ldloc o);
  emit k (Il.Brfalse no);
  List.iter
    (fun ((f, ty) : int * S.t) ->
      emit k (Il.Ldarg 0);
      emit k (Il.Ldfld f);
      box ty k;
      emit k (Il.Ldloc o);
      emit k (Il.Ldfld f);
      box ty k;
      (match ty with
       | S.String -> emit k (Il.Call (lib c "String" "op_Equality" (static [ S.String; S.String ] S.Bool)))
       | S.Class _ | S.GenericInst _ | S.Var _ -> emit k (Il.Callvirt (lib c "Object" "Equals" (instance [ S.Object ] S.Bool)))
       | _ -> emit k Il.Ceq);
      emit k (Il.Brfalse no))
    fields;
  emit k (Il.Ldc_i4 1l);
  emit k Il.Ret;
  place k no;
  emit k (Il.Ldc_i4 0l);
  emit k Il.Ret;
  finish c k eq;
  let hash = W.method_def c.w t.tok "GetHashCode" 0x00C6 (instance [] S.I4) in
  let k = new_code () in
  emit k (Il.Ldc_i4 (Int32.of_int tag));
  List.iter
    (fun ((f, ty) : int * S.t) ->
      emit k (Il.Ldc_i4 31l);
      emit k (Il.Binop Il.Mul);
      emit k (Il.Ldarg 0);
      emit k (Il.Ldfld f);
      (match ty with
       | S.I8 ->
           (* (its two halves mixed) *)
           emit k Il.Dup;
           emit k (Il.Ldc_i4 32l);
           emit k (Il.Binop Il.Shr);
           emit k (Il.Binop Il.Xor);
           emit k (Il.Conv (Il.K_i4, false, false))
       | S.R8 -> emit k (Il.Box (sys c "Double")); emit k (Il.Callvirt (lib c "Object" "GetHashCode" (instance [] S.I4)))
       | S.Var _ -> box ty k; emit k (Il.Callvirt (lib c "Object" "GetHashCode" (instance [] S.I4)))
       | S.String | S.Class _ | S.GenericInst _ -> emit k (Il.Callvirt (lib c "Object" "GetHashCode" (instance [] S.I4)))
       | _ -> ());
      emit k (Il.Binop Il.Add))
    fields;
  emit k Il.Ret;
  finish c k hash

(* a constructor taking the fields in order, after its parent's *)
let constructor (c : c) (t : tclass) (parent_ctor : int) : unit =
  let ctor = W.method_def c.w t.tok ".ctor" 0x1886 (instance (List.map snd t.fields) S.Void) in
  t.ctor <- ctor;
  let me = own t in
  let k = new_code () in
  emit k (Il.Ldarg 0);
  emit k (Il.Call parent_ctor);
  List.iteri
    (fun (i : int) (_ : string * S.t) ->
      emit k (Il.Ldarg 0);
      emit k (Il.Ldarg (i + 1));
      emit k (Il.Stfld (field_tok c t me i)))
    t.fields;
  emit k Il.Ret;
  finish c k ctor

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

let decl (t : Scope.ty) : Scope.tdecl = match t with Tconstr (d, _) -> d | _ -> assert false
let int_d = decl Resolve.int_t and bool_d = decl Resolve.bool_t and unit_d = decl Resolve.unit_t
let char_d = decl Resolve.char_t and float_d = decl Resolve.float_t and string_d = decl Resolve.string_t
let exn_d = decl Resolve.exn_t

(* a type's namespace and name: a path's own, else the unit's *)
let split (c : c) (path : string) : string * string =
  match String.rindex_opt path '.' with
  | Some i -> (String.sub path 0 i, String.sub path (i + 1) (String.length path - i - 1))
  | None -> (c.uname, path)

(* a type's class made: of the unit, nested in the unit's (F#'s modules:
 * so C# names it Unit.t, and no namespace has the unit's class's name);
 * of Pervasives (ref, option), in the namespace Stdlib of this assembly
 * (until several units: stage 1e); another unit's, not yet. Generic,
 * t`1 as .NET names it, its parameters T0... [flags]: its own, the
 * visibility added *)
let make_class (c : c) (loc : int) (path : string) (arity : int) (flags : int) (parent : int) : int =
  let ns, name = split c path in
  let name = if arity > 0 then Printf.sprintf "%s`%d" name arity else name in
  let cls =
    if ns = c.uname then begin
      let cls = W.type_def c.w "" name (flags lor 0x2) parent in
      W.nest c.w cls c.cls;
      cls
    end
    else if ns = "Pervasives" then W.type_def c.w "Stdlib" name (flags lor 0x1) parent
    else refuse loc ("the type " ^ path ^ ", of another unit") "1e" in
  for i = 0 to arity - 1 do
    W.generic_param c.w cls i (Printf.sprintf "T%d" i)
  done;
  cls

(* a declaration's type parameters made a class's own (!0...) while [f]
 * makes its fields' types *)
let in_class (c : c) (params : string list) (f : unit -> 'a) : 'a =
  let saved = c.tvars in
  c.tvars <- List.mapi (fun (i : int) (p : string) -> (p, S.Var i)) params;
  let x = f () in
  c.tvars <- saved;
  x

(* a declared type with its parameters given *)
let rec subst (params : string list) (args : Scope.ty list) (t : Scope.ty) : Scope.ty =
  match t with
  | Tvar n -> (match List.assoc_opt n (List.combine params args) with Some a -> a | None -> t)
  | Tarrow (a, b) -> Tarrow (subst params args a, subst params args b)
  | Ttuple ts -> Ttuple (List.map (subst params args) ts)
  | Tconstr (d, ts) -> Tconstr (d, List.map (subst params args) ts)

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
  | Tconstr (d, args) when Resolve.type_fields d <> None -> at (record c loc d) (List.map (arg_type c loc) args)
  | Tconstr (d, args) when Resolve.type_conses d <> None -> at (variant c loc d) (List.map (arg_type c loc) args)
  (* (a polymorphic function's variable its method's parameter; one
   * that nothing constrains, an object) *)
  | Tvar n -> (match List.assoc_opt n c.tvars with Some t -> t | None -> S.Object)
  | Tarrow (a, b) -> func c loc a b
  | Ttuple _ -> refuse loc "a tuple" "1d"
  | Tconstr (d, _) -> refuse loc ("a value of type " ^ d.tpath) "1d"

(* a type as a type argument (a Func's, a generic class's): unit an
 * object, always null (F#'s unit: .NET has no void type argument) *)
and arg_type (c : c) (loc : int) (t : Scope.ty) : S.t = match cts c loc t with S.Void -> S.Object | t -> t

(* a function, System.Func<A, B>: curried as ML's, int -> int -> int a
 * Func<long, Func<long, long>> *)
and func (c : c) (loc : int) (a : Scope.ty) (b : Scope.ty) : S.t =
  S.GenericInst (S.Class (sys c "Func`2"), [ arg_type c loc a; arg_type c loc b ])

(* a record type: a class of its fields, in their order *)
and record (c : c) (loc : int) (d : Scope.tdecl) : tclass =
  match Hashtbl.find_opt classes d.tpath with
  | Some t -> t
  | None ->
      let labels = match Resolve.type_fields d with Some l -> l | None -> [] in
      let labels = List.sort (fun ((_, a) : string * Scope.label) ((_, b) : string * Scope.label) -> compare a.pos b.pos) labels in
      let arity = List.length d.tparams in
      (* (known before its fields' types, which may be its own: a type of
       * the metadata is its token, known at once) *)
      let t = { tok = make_class c loc d.tpath arity 0x00100000 (sys c "Object"); arity; fields = []; ftoks = []; ctor = 0 } in
      Hashtbl.replace classes d.tpath t;
      t.fields <-
        List.map
          (fun ((n, l) : string * Scope.label) ->
            let params, ty, _ = l.ltype in
            (n, in_class c params (fun () -> arg_type c loc ty)))
          labels;
      t.ftoks <- List.map (fun ((n, ty) : string * S.t) -> W.field_def c.w t.tok n 0x0006 ty) t.fields;
      constructor c t (object_ctor c);
      structural c t 0;
      t

(* a variant type: an abstract class, and a class of each constructor's,
 * nested in it, its fields the constructor's arguments (Item1...);
 * generic, each a class of the same parameters, its parent the
 * variant's at them *)
and variant (c : c) (loc : int) (d : Scope.tdecl) : tclass =
  match Hashtbl.find_opt classes d.tpath with
  | Some t -> t
  | None ->
      let arity = List.length d.tparams in
      let t = { tok = make_class c loc d.tpath arity 0x00100080 (sys c "Object"); arity; fields = []; ftoks = []; ctor = 0 } in
      Hashtbl.replace classes d.tpath t;
      constructor c t (object_ctor c);
      let me = own t in
      let parent = type_tok c t me and parent_ctor = ctor_tok c t me in
      List.iteri
        (fun (tag : int) ((cname, k) : string * Scope.cons) ->
          if k.cinline <> [] then refuse loc (cname ^ ", a constructor of an inline record") "1b";
          let params, args, _ = k.ctype in
          let name = if arity > 0 then Printf.sprintf "%s`%d" cname arity else cname in
          let tok = W.type_def c.w "" name 0x00100102 parent in
          W.nest c.w tok t.tok;
          for i = 0 to arity - 1 do
            W.generic_param c.w tok i (Printf.sprintf "T%d" i)
          done;
          let case = { tok; arity; fields = []; ftoks = []; ctor = 0 } in
          case.fields <-
            List.mapi (fun (i : int) (ty : Scope.ty) -> (Printf.sprintf "Item%d" (i + 1), in_class c params (fun () -> arg_type c loc ty))) args;
          case.ftoks <- List.map (fun ((n, ty) : string * S.t) -> W.field_def c.w tok n 0x0006 ty) case.fields;
          constructor c case parent_ctor;
          structural c case tag;
          Hashtbl.replace classes (d.tpath ^ "|" ^ cname) case)
        (match Resolve.type_conses d with Some l -> l | None -> []);
      t

(* a record's type's class and its type arguments *)
let record_at (c : c) (loc : int) (ty : Scope.ty) : tclass * S.t list =
  match ty with
  | Tconstr (d, args) -> (record c loc d, List.map (arg_type c loc) args)
  | _ -> refuse loc "a record of no record type" "1b"

(* the index of a record's field, by its name *)
let index (t : tclass) (name : string) : int =
  let rec go (i : int) (l : (string * S.t) list) : int =
    match l with (n, _) :: rest -> if n = name then i else go (i + 1) rest | [] -> raise Not_found in
  go 0 t.fields

let field (c : c) (loc : int) (ty : Scope.ty) (name : string) : int =
  let t, args = record_at c loc ty in
  field_tok c t args (index t name)

let field0 (c : c) (loc : int) (ty : Scope.ty) : int =
  let t, args = record_at c loc ty in
  field_tok c t args 0

let record_ctor (c : c) (loc : int) (ty : Scope.ty) : int =
  let t, args = record_at c loc ty in
  ctor_tok c t args

(* a constructor of a variant at the variant's type: its class's token,
 * its constructor, its fields, its arguments' types there *)
let case (c : c) (loc : int) (k : Scope.cons) (ty : Scope.ty) : int * int * (int -> int) * Scope.ty list =
  let params, targs, res = k.ctype in
  let d = decl res in
  let inst = match ty with Tconstr (_, a) -> a | _ -> [] in
  ignore (variant c loc d);
  let t = Hashtbl.find classes (d.tpath ^ "|" ^ k.cname) in
  let args = List.map (arg_type c loc) inst in
  let types = if List.length params = List.length inst then List.map (subst params inst) targs else targs in
  (type_tok c t args, ctor_tok c t args, field_tok c t args, types)

(* a record's fields' types at the record's type, by label *)
let label_type (l : Scope.label) (ty : Scope.ty) : Scope.ty =
  let params, fty, _ = l.ltype in
  match ty with Tconstr (_, inst) when List.length params = List.length inst -> subst params inst fty | _ -> fty

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

(* OCaml's compare of two values of a type variable, boxed: the
 * assembly's helper Stdlib.Ml::compare(object, object), made once: a
 * string's ordinal, an int's, a float's, a char's, a boolean's order;
 * another value (a record's, a variant's: OCaml's structural order, not
 * yet) an exception *)
let ml_compare (c : c) : int =
  memo c "ml compare" (fun () ->
      let cls = W.type_def c.w "Stdlib" "Ml" 0x00100181 (sys c "Object") in
      let m = W.method_def c.w cls "compare" 0x0096 (static [ S.Object; S.Object ] S.I4) in
      let k = new_code () in
      let order (ty : string) (t : S.t) =
        (* (a < b: -1, a > b: 1, else 0) *)
        let next = label k in
        emit k (Il.Ldarg 0);
        emit k (Il.Isinst (sys c ty));
        emit k (Il.Brfalse next);
        let x = local k t and y = local k t in
        emit k (Il.Ldarg 0); emit k (Il.Unbox_any (sys c ty)); emit k (Il.Stloc x);
        emit k (Il.Ldarg 1); emit k (Il.Unbox_any (sys c ty)); emit k (Il.Stloc y);
        let not_less = label k and not_more = label k in
        emit k (Il.Ldloc x); emit k (Il.Ldloc y); emit k (Il.Clt false); emit k (Il.Brfalse not_less);
        emit k (Il.Ldc_i4 (-1l)); emit k Il.Ret;
        place k not_less;
        emit k (Il.Ldloc x); emit k (Il.Ldloc y); emit k (Il.Cgt false); emit k (Il.Brfalse not_more);
        emit k (Il.Ldc_i4 1l); emit k Il.Ret;
        place k not_more;
        emit k (Il.Ldc_i4 0l); emit k Il.Ret;
        place k next in
      let not_string = label k in
      emit k (Il.Ldarg 0);
      emit k (Il.Isinst (sys c "String"));
      emit k (Il.Brfalse not_string);
      emit k (Il.Ldarg 0); emit k (Il.Castclass (sys c "String"));
      emit k (Il.Ldarg 1); emit k (Il.Castclass (sys c "String"));
      emit k (Il.Call (lib c "String" "CompareOrdinal" (static [ S.String; S.String ] S.I4)));
      emit k Il.Ret;
      place k not_string;
      order "Int64" S.I8;
      order "Double" S.R8;
      order "Int32" S.I4;
      order "Boolean" S.Bool;
      emit k (Il.Ldstr (W.user_string c.w "compare: a record's or a variant's order, at a type variable"));
      emit k (Il.Newobj (lib c "Exception" ".ctor" (instance [ S.String ] S.Void)));
      emit k Il.Throw;
      finish c k m;
      m)
