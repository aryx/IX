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

(* the types of the expressions this back end makes (a primitive as a
 * value, η-expanded), by their spans, which no source has *)
let synthetic : (Ast.span, Scope.ty) Hashtbl.t = Hashtbl.create 16

(* and of the variables those bind (by their ids, negative) *)
let synthetic_vars : (int, Scope.ty) Hashtbl.t = Hashtbl.create 16

let var_type (vid : int) : Scope.ty option =
  match Hashtbl.find_opt synthetic_vars vid with Some t -> Some t | None -> Typing.var_type vid

(* the types the assembly's units declare, by path: what another unit,
 * whose .mli says type t abstract, sees of them (Uchar.utf_decode an
 * int) *)
let implementations : (string, Scope.tdecl) Hashtbl.t = Hashtbl.create 64

(* a type's key among the classes: its path, a unit's own qualified by
 * the unit (Asm's mem is Asm.mem in Opti; two units' t two classes);
 * the predefined list as it is *)
let qkey (c : c) (d : Scope.tdecl) : string =
  if d == Resolve.list_d || String.contains d.tpath '.' then d.tpath else c.uname ^ "." ^ d.tpath

(* a constant constructor's class: its static field Instance *)
let instances : (int, int) Hashtbl.t = Hashtbl.create 16

let reset () : unit =
  Hashtbl.reset classes; Hashtbl.reset synthetic; Hashtbl.reset synthetic_vars; Hashtbl.reset implementations;
  Hashtbl.reset instances

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

(* a constant constructor's one value (OCaml's None == None): its
 * class's static field Instance, made by its .cctor, at type arguments *)
let instance_tok (c : c) (t : tclass) (args : S.t list) : int =
  if t.arity = 0 then Hashtbl.find instances t.tok
  else
    memo c ("instance " ^ S.encode_type_spec (at t args)) (fun () ->
        W.field_ref c.w (W.type_spec c.w (at t args)) "Instance" (at t (own t)))

(* a method of such a class at its instance: the MethodDef, or a
 * MemberRef of the instance, its signature the declared one *)
let method_tok (c : c) (t : tclass) (args : S.t list) (name : string) (tok : int) (m : S.meth) : int =
  if t.arity = 0 then tok
  else memo c ("method " ^ S.encode_type_spec (at t args) ^ "." ^ name) (fun () -> W.member_ref c.w (W.type_spec c.w (at t args)) name m)

(* the assembly's class of ML's helpers, Stdlib.Ml (compare, hash) *)
let ml_class (c : c) : int =
  memo c "type Stdlib.Ml" (fun () -> W.type_def c.w "Stdlib" "Ml" 0x00100181 (sys c "Object"))

(* OCaml's compare of two values of a type variable, boxed: the
 * assembly's helper Stdlib.Ml::compare(object, object), made once: a
 * string's ordinal, an int's, a float's, a char's, a boolean's order;
 * another value (a record's, a variant's: OCaml's structural order, not
 * yet) an exception *)
let ml_compare (c : c) : int =
  memo c "ml compare" (fun () ->
      let cls = ml_class c in
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
      (* (unit, null: equal to itself, before anything else) *)
      let a_set = label k and b_set = label k in
      emit k (Il.Ldarg 0); emit k (Il.Brtrue a_set);
      emit k (Il.Ldarg 1); emit k (Il.Ldnull); emit k (Il.Cgt true); emit k (Il.Neg); emit k Il.Ret;
      place k a_set;
      emit k (Il.Ldarg 1); emit k (Il.Brtrue b_set);
      emit k (Il.Ldc_i4 1l); emit k Il.Ret;
      place k b_set;
      (* (a string's: CompareOrdinal's sign, -1, 0 or 1 as OCaml's) *)
      let not_string = label k in
      emit k (Il.Ldarg 0);
      emit k (Il.Isinst (sys c "String"));
      emit k (Il.Brfalse not_string);
      let d = local k S.I4 in
      emit k (Il.Ldarg 0); emit k (Il.Castclass (sys c "String"));
      emit k (Il.Ldarg 1); emit k (Il.Castclass (sys c "String"));
      emit k (Il.Call (lib c "String" "CompareOrdinal" (static [ S.String; S.String ] S.I4)));
      emit k (Il.Stloc d);
      emit k (Il.Ldloc d); emit k (Il.Ldc_i4 0l); emit k (Il.Cgt false);
      emit k (Il.Ldloc d); emit k (Il.Ldc_i4 0l); emit k (Il.Clt false);
      emit k (Il.Binop Il.Sub);
      emit k Il.Ret;
      place k not_string;
      order "Int64" S.I8;
      order "Double" S.R8;
      order "Int32" S.I4;
      order "Boolean" S.Bool;
      (* (a record's, a variant's, a tuple's, a list's: their CompareTo,
       * structural, IComparable's) *)
      let none = label k in
      emit k (Il.Ldarg 0); emit k (Il.Isinst (sys c "IComparable")); emit k (Il.Brfalse none);
      emit k (Il.Ldarg 0); emit k (Il.Castclass (sys c "IComparable")); emit k (Il.Ldarg 1);
      emit k (Il.Callvirt (lib c "IComparable" "CompareTo" (instance [ S.Object ] S.I4)));
      emit k Il.Ret;
      place k none;
      emit k (Il.Ldstr (W.user_string c.w "compare: a value of no order (a function, an array)"));
      emit k (Il.Newobj (lib c "Exception" ".ctor" (instance [ S.String ] S.Void)));
      emit k Il.Throw;
      finish c k m;
      m)

(* = of two arrays (OCaml's: their lengths and elements, not their
 * places): the assembly's helper Stdlib.Ml::array_equal<T>(T[], T[]),
 * each pair of elements by Object.Equals, boxed (a record's, a
 * variant's structural, a number's or a string's by value); an array
 * inside a record or another array still compared as a place *)
let ml_array_equal (c : c) : int =
  memo c "ml array_equal" (fun () ->
      let cls = ml_class c in
      let a = S.SzArray (S.MVar 0) in
      let m = W.method_def c.w cls "array_equal" 0x0096 { (static [ a; a ] S.Bool) with generic = 1 } in
      W.generic_param c.w m 0 "T";
      let t = W.type_spec c.w (S.MVar 0) in
      let k = new_code () in
      let yes = label k and no = label k and top = label k in
      let i = local k S.I4 in
      emit k (Il.Ldarg 0); emit k (Il.Ldarg 1); emit k (Il.Bcmp (Il.Eq, false, yes));
      emit k (Il.Ldarg 0); emit k (Il.Brfalse no);
      emit k (Il.Ldarg 1); emit k (Il.Brfalse no);
      emit k (Il.Ldarg 0); emit k Il.Ldlen; emit k (Il.Conv (Il.K_i4, false, false));
      emit k (Il.Ldarg 1); emit k Il.Ldlen; emit k (Il.Conv (Il.K_i4, false, false));
      emit k (Il.Bcmp (Il.Ne, true, no));
      emit k (Il.Ldc_i4 0l); emit k (Il.Stloc i);
      place k top;
      emit k (Il.Ldloc i); emit k (Il.Ldarg 0); emit k Il.Ldlen; emit k (Il.Conv (Il.K_i4, false, false));
      emit k (Il.Bcmp (Il.Ge, false, yes));
      emit k (Il.Ldarg 0); emit k (Il.Ldloc i); emit k (Il.Ldelem_any t); emit k (Il.Box t);
      emit k (Il.Ldarg 1); emit k (Il.Ldloc i); emit k (Il.Ldelem_any t); emit k (Il.Box t);
      emit k (Il.Call (lib c "Object" "Equals" (static [ S.Object; S.Object ] S.Bool)));
      emit k (Il.Brfalse no);
      emit k (Il.Ldloc i); emit k (Il.Ldc_i4 1l); emit k (Il.Binop Il.Add); emit k (Il.Stloc i);
      emit k (Il.Br top);
      place k yes; emit k (Il.Ldc_i4 1l); emit k Il.Ret;
      place k no; emit k (Il.Ldc_i4 0l); emit k Il.Ret;
      finish c k m;
      m)

(* OCaml's Hashtbl.hash of a value: the assembly's helper
 * Stdlib.Ml::hash(object), made once, the same on every runtime (.NET's
 * String.GetHashCode is not: Microsoft's varies by process): a
 * string's chars (h * 31 + c), an int64's halves, a float's bits, an
 * int32's or a boolean's value, an ML value's structural GetHashCode
 * (which hashes its fields here), null 0 *)
let ml_hash (c : c) : int =
  memo c "ml hash" (fun () ->
      let cls = ml_class c in
      let m = W.method_def c.w cls "hash" 0x0096 (static [ S.Object ] S.I4) in
      let k = new_code () in
      let set = label k in
      emit k (Il.Ldarg 0); emit k (Il.Brtrue set); emit k (Il.Ldc_i4 0l); emit k Il.Ret;
      place k set;
      (* a string *)
      let not_string = label k in
      emit k (Il.Ldarg 0); emit k (Il.Isinst (sys c "String")); emit k (Il.Brfalse not_string);
      let str = local k S.String and h = local k S.I4 and i = local k S.I4 in
      let top = label k and over = label k in
      emit k (Il.Ldarg 0); emit k (Il.Castclass (sys c "String")); emit k (Il.Stloc str);
      emit k (Il.Ldc_i4 0l); emit k (Il.Stloc h);
      emit k (Il.Ldc_i4 0l); emit k (Il.Stloc i);
      place k top;
      emit k (Il.Ldloc i); emit k (Il.Ldloc str);
      emit k (Il.Callvirt (lib c "String" "get_Length" (instance [] S.I4)));
      emit k (Il.Clt false); emit k (Il.Brfalse over);
      emit k (Il.Ldloc h); emit k (Il.Ldc_i4 31l); emit k (Il.Binop Il.Mul);
      emit k (Il.Ldloc str); emit k (Il.Ldloc i);
      emit k (Il.Callvirt (lib c "String" "get_Chars" (instance [ S.I4 ] S.Char)));
      emit k (Il.Binop Il.Add); emit k (Il.Stloc h);
      emit k (Il.Ldloc i); emit k (Il.Ldc_i4 1l); emit k (Il.Binop Il.Add); emit k (Il.Stloc i);
      emit k (Il.Br top);
      place k over;
      emit k (Il.Ldloc h); emit k Il.Ret;
      place k not_string;
      (* an int64, a float (its bits): the two halves *)
      let halves () =
        emit k Il.Dup; emit k (Il.Ldc_i4 32l); emit k (Il.Binop Il.Shr); emit k (Il.Binop Il.Xor);
        emit k (Il.Conv (Il.K_i4, false, false)); emit k Il.Ret in
      let not_long = label k in
      emit k (Il.Ldarg 0); emit k (Il.Isinst (sys c "Int64")); emit k (Il.Brfalse not_long);
      emit k (Il.Ldarg 0); emit k (Il.Unbox_any (sys c "Int64")); halves ();
      place k not_long;
      let not_double = label k in
      emit k (Il.Ldarg 0); emit k (Il.Isinst (sys c "Double")); emit k (Il.Brfalse not_double);
      emit k (Il.Ldarg 0); emit k (Il.Unbox_any (sys c "Double"));
      emit k (Il.Call (lib c "BitConverter" "DoubleToInt64Bits" (static [ S.R8 ] S.I8))); halves ();
      place k not_double;
      let value (name : string) (t : S.t) =
        let next = label k in
        emit k (Il.Ldarg 0); emit k (Il.Isinst (sys c name)); emit k (Il.Brfalse next);
        emit k (Il.Ldarg 0); emit k (Il.Unbox_any (sys c name));
        if t = S.Bool then emit k (Il.Conv (Il.K_i4, false, false));
        emit k Il.Ret;
        place k next in
      value "Int32" S.I4;
      value "Boolean" S.Bool;
      (* an ML value's, and any other's *)
      emit k (Il.Ldarg 0);
      emit k (Il.Callvirt (lib c "Object" "GetHashCode" (instance [] S.I4)));
      emit k Il.Ret;
      finish c k m;
      m)

(* structural equality, F#'s: Equals of an object of the same class
 * whose fields are equal (an int's, a float's, a string's text, an ML
 * value's own Equals, a type parameter's boxed), and GetHashCode of the
 * fields', so that = is a call of Equals, and a .NET set or dictionary
 * holds ML values as OCaml's = sees them *)
let structural (c : c) (t : tclass) (tag : int) (variant : (tclass * int * int) option) : unit =
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
       (* (the others by Ml::hash: a string's the same everywhere, null's 0) *)
       | S.R8 -> emit k (Il.Box (sys c "Double")); emit k (Il.Call (ml_hash c))
       | S.Var _ -> box ty k; emit k (Il.Call (ml_hash c))
       | S.String | S.Class _ | S.GenericInst _ -> emit k (Il.Call (ml_hash c))
       (* (an abstract type's object, an array: Equals compares their
        * references, so nothing of theirs) *)
       | S.Object | S.SzArray _ -> emit k Il.Pop; emit k (Il.Ldc_i4 0l)
       | _ -> ());
      emit k (Il.Binop Il.Add))
    fields;
  emit k Il.Ret;
  finish c k hash;
  (* CompareTo, OCaml's order (IComparable's, which Ml::compare calls):
   * a variant's constructors by their order ([variant]: the parent,
   * its ml_order, this one's: OCaml's constants before its blocks),
   * then the fields in turn *)
  let cmp = W.method_def c.w t.tok "CompareTo" 0x01E6 (instance [ S.Object ] S.I4) in
  W.implements c.w t.tok (sys c "IComparable");
  let k = new_code () in
  (match variant with
   | Some (parent, ord, order) ->
       let other = local k S.I4 and same = label k and more = label k in
       emit k (Il.Ldarg 1);
       emit k (Il.Castclass (type_tok c parent me));
       emit k (Il.Callvirt (method_tok c parent me "ml_order" ord (instance [] S.I4)));
       emit k (Il.Stloc other);
       emit k (Il.Ldc_i4 (Int32.of_int order)); emit k (Il.Ldloc other); emit k Il.Ceq; emit k (Il.Brtrue same);
       emit k (Il.Ldc_i4 (Int32.of_int order)); emit k (Il.Ldloc other); emit k (Il.Clt false); emit k (Il.Brfalse more);
       emit k (Il.Ldc_i4 (-1l)); emit k Il.Ret;
       place k more;
       emit k (Il.Ldc_i4 1l); emit k Il.Ret;
       place k same
   | None -> ());
  let y = local k (at t me) and over = label k in
  emit k (Il.Ldarg 1); emit k (Il.Castclass (type_tok c t me)); emit k (Il.Stloc y);
  let boxed (ty : S.t) =
    match ty with
    | S.I8 -> emit k (Il.Box (sys c "Int64"))
    | S.R8 -> emit k (Il.Box (sys c "Double"))
    | S.I4 -> emit k (Il.Box (sys c "Int32"))
    | S.Bool -> emit k (Il.Box (sys c "Boolean"))
    | S.Var _ | S.MVar _ -> emit k (Il.Box (W.type_spec c.w ty))
    | _ -> () in
  List.iter
    (fun ((f, ty) : int * S.t) ->
      emit k (Il.Ldarg 0); emit k (Il.Ldfld f); boxed ty;
      emit k (Il.Ldloc y); emit k (Il.Ldfld f); boxed ty;
      emit k (Il.Call (ml_compare c));
      emit k Il.Dup; emit k (Il.Brtrue over); emit k Il.Pop)
    fields;
  emit k (Il.Ldc_i4 0l); emit k Il.Ret;
  place k over;
  emit k Il.Ret;
  finish c k cmp

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

(* a class of the lowering's own (a closure's, a partial application's):
 * nested in the unit's class, sealed, generic in [arity] parameters
 * (the enclosing method's or class's type variables, its own !0...),
 * its fields (declared in those) set by its constructor *)
let helper_class (c : c) (name : string) (arity : int) (fields : (string * S.t) list) : tclass =
  let tok = W.type_def c.w "" (if arity > 0 then Printf.sprintf "%s`%d" name arity else name) 0x00100102 (sys c "Object") in
  W.nest c.w tok c.cls;
  for i = 0 to arity - 1 do
    W.generic_param c.w tok i (Printf.sprintf "T%d" i)
  done;
  let t = { tok; arity; fields; ftoks = List.map (fun ((n, ty) : string * S.t) -> W.field_def c.w tok n 0x0006 ty) fields; ctor = 0 } in
  constructor c t (object_ctor c);
  t

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

let decl (t : Scope.ty) : Scope.tdecl = match t with Tconstr (d, _) -> d | _ -> assert false
let int_d = decl Resolve.int_t and bool_d = decl Resolve.bool_t and unit_d = decl Resolve.unit_t
let char_d = decl Resolve.char_t and float_d = decl Resolve.float_t and string_d = decl Resolve.string_t
let exn_d = decl Resolve.exn_t

(* the list's constructors, the language's own, which Resolve's tables
 * of a type's constructors have not (they are Resolve's predefined
 * ones, as written there) *)
let list_conses : (string * Scope.cons) list =
  let list = Scope.Tconstr (Resolve.list_d, [ Tvar "a" ]) in
  [ ("[]", { cname = "[]"; kind = Const 0; arity = 0; nconst = 1; nblock = 1; ctype = ([ "a" ], [], list); cinline = [] });
    ("::", { cname = "::"; kind = Block 0; arity = 2; nconst = 1; nblock = 1; ctype = ([ "a" ], [ Tvar "a"; list ], list); cinline = [] }) ]

let conses (d : Scope.tdecl) : (string * Scope.cons) list option =
  if d == Resolve.list_d then Some list_conses else Resolve.type_conses d

(* a type's namespace and name: a path's own, else the unit's *)
let split (c : c) (path : string) : string * string =
  match String.rindex_opt path '.' with
  | Some i -> (String.sub path 0 i, String.sub path (i + 1) (String.length path - i - 1))
  | None -> (c.uname, path)

(* a unit's class, this one's or one compiled before it in the
 * assembly *)
let unit_class (c : c) (name : string) : int option =
  if name = c.uname then Some c.cls else Hashtbl.find_opt c.memo ("unit " ^ name)

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
    match unit_class c ns with
    | Some outer ->
        let cls = W.type_def c.w "" name (flags lor 0x2) parent in
        W.nest c.w cls outer;
        cls
    | None when ns = "Pervasives" -> W.type_def c.w "Stdlib" name (flags lor 0x1) parent
    | None -> refuse loc ("the type " ^ path ^ ", of a unit not compiled with it") "1e" in
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

(* a type's abbreviations expanded at its top: 'a msgf to the function
 * it is *)
let rec unabbrev (t : Scope.ty) : Scope.ty =
  match t with Tconstr ({ tabbrev = Some a; tparams; _ }, args) -> unabbrev (subst tparams args a) | t -> t

(* an ML type's .NET type; unit's Void (no value) *)
let rec cts (c : c) (loc : int) (t : Scope.ty) : S.t =
  match t with
  | Tconstr (d, []) when d == int_d -> S.I8
  | Tconstr (d, []) when d == bool_d -> S.Bool
  | Tconstr (d, []) when d == char_d -> S.I4
  | Tconstr (d, []) when d == float_d -> S.R8
  | Tconstr (d, []) when d == string_d -> S.String
  (* (bytes, .NET's byte[]: a channel's Stream reads and writes them) *)
  | Tconstr (d, []) when d.tpath = "bytes" -> S.SzArray S.U1
  (* (int64 and int32, lib_core's abstract Int64.t and Int32.t: .NET's
   * own, unboxed) *)
  | Tconstr (d, []) when d.tpath = "Int64.t" -> S.I8
  | Tconstr (d, []) when d.tpath = "Int32.t" -> S.I4
  (* (Float.Array.t, OCaml's floatarray: .NET's float64[]) *)
  | Tconstr (d, []) when d.tpath = "Float.Array.t" -> S.SzArray S.R8
  | Tconstr (d, []) when d == unit_d -> S.Void
  | Tconstr (d, []) when d == exn_d -> S.Class (sys c "Exception")
  | Tconstr ({ tabbrev = Some t; _ }, []) -> cts c loc t
  | Tconstr ({ tabbrev = Some t; tparams; _ }, args) -> cts c loc (subst tparams args t)
  | Tconstr (d, args) when Resolve.type_fields d <> None -> at (record c loc d) (List.map (arg_type c loc) args)
  | Tconstr (d, args) when conses d <> None -> at (variant c loc d) (List.map (arg_type c loc) args)
  (* (a polymorphic function's variable its method's parameter; one
   * that nothing constrains, an object) *)
  | Tvar n -> (match List.assoc_opt n c.tvars with Some t -> t | None -> S.Object)
  | Tarrow (a, b) -> func c loc a b
  | Ttuple ts -> at (tuple c loc (List.length ts)) (List.map (arg_type c loc) ts)
  (* (an array, .NET's own: T[]) *)
  | Tconstr (d, [ a ]) when d == Resolve.array_d -> S.SzArray (arg_type c loc a)
  (* (a format, ('a, 'b, 'c, 'd) format4: a function of k : string ->
   * 'd, the curried function of its arguments, k of their text; F#'s
   * way, typed, a literal's compiled: Il_exprs.format_value) *)
  | Tconstr (d, [ a; _; _; dd ]) when d.tpath = "format4" -> func c loc (Tarrow (Resolve.string_t, dd)) a
  (* (a type abstract in its unit's .mli, defined in its .ml, compiled
   * in this assembly: that definition) *)
  | Tconstr (d, args) when d.tabbrev = None && (match Hashtbl.find_opt implementations d.tpath with Some d' -> d' != d | None -> false) ->
      cts c loc (Tconstr (Hashtbl.find implementations d.tpath, args))
  (* (a unit's abstract type, Pervasives' in_channel: an object, which
   * the runtime unit casts to what it is) *)
  | Tconstr (d, _) when d.tabbrev = None && String.contains d.tpath '.' -> S.Object
  | Tconstr (d, _) -> refuse loc ("a value of type " ^ d.tpath) "1d"

(* a type as a type argument (a Func's, a generic class's): unit an
 * object, always null (F#'s unit: .NET has no void type argument) *)
and arg_type (c : c) (loc : int) (t : Scope.ty) : S.t = match cts c loc t with S.Void -> S.Object | t -> t

(* a function, System.Func<A, B>: curried as ML's, int -> int -> int a
 * Func<long, Func<long, long>> *)
and func (c : c) (loc : int) (a : Scope.ty) (b : Scope.ty) : S.t =
  S.GenericInst (S.Class (sys c "Func`2"), [ arg_type c loc a; arg_type c loc b ])

(* a record type: a class of its fields, in their order; seen from
 * another unit, its declaration the unit's own (implementations: its
 * fields there) *)
and record (c : c) (loc : int) (d : Scope.tdecl) : tclass =
  let key = qkey c d in
  match Hashtbl.find_opt classes key with
  | Some t -> t
  | None ->
      let d = match Resolve.type_fields d, Hashtbl.find_opt implementations key with
        | None, Some d' -> d' | _ -> d in
      let labels = match Resolve.type_fields d with Some l -> l | None -> [] in
      let labels = List.sort (fun ((_, a) : string * Scope.label) ((_, b) : string * Scope.label) -> compare a.pos b.pos) labels in
      let arity = List.length d.tparams in
      (* (known before its fields' types, which may be its own: a type of
       * the metadata is its token, known at once) *)
      let t = { tok = make_class c loc (if String.contains d.tpath '.' then d.tpath else key) arity 0x00100000 (sys c "Object"); arity; fields = []; ftoks = []; ctor = 0 } in
      Hashtbl.replace classes key t;
      t.fields <-
        List.map
          (fun ((n, l) : string * Scope.label) ->
            let params, ty, _ = l.ltype in
            (n, in_class c params (fun () -> arg_type c loc ty)))
          labels;
      t.ftoks <- List.map (fun ((n, ty) : string * S.t) -> W.field_def c.w t.tok n 0x0006 ty) t.fields;
      constructor c t (object_ctor c);
      structural c t 0 None;
      t

(* a tuple of n: ML's own class, Stdlib.tuple`n, its fields Item1...
 * (System.ValueTuple's names: mini-dotnet's library has not got it) *)
and tuple (c : c) (loc : int) (n : int) : tclass =
  let key = Printf.sprintf "tuple %d" n in
  match Hashtbl.find_opt classes key with
  | Some t -> t
  | None ->
      let t = { tok = make_class c loc "Pervasives.tuple" n 0x00100100 (sys c "Object"); arity = n; fields = []; ftoks = []; ctor = 0 } in
      Hashtbl.replace classes key t;
      t.fields <- List.init n (fun (i : int) -> (Printf.sprintf "Item%d" (i + 1), S.Var i));
      t.ftoks <- List.map (fun ((f, ty) : string * S.t) -> W.field_def c.w t.tok f 0x0006 ty) t.fields;
      constructor c t (object_ctor c);
      structural c t 0 None;
      t

(* a variant type: an abstract class, and a class of each constructor's,
 * nested in it, its fields the constructor's arguments (Item1...);
 * generic, each a class of the same parameters, its parent the
 * variant's at them *)
and variant (c : c) (loc : int) (d : Scope.tdecl) : tclass =
  let key = qkey c d in
  match Hashtbl.find_opt classes key with
  | Some t -> t
  | None ->
      let arity = List.length d.tparams in
      (* (OCaml's list, a variant of the language's: Stdlib's too, its
       * constructors' classes Nil and Cons, names that C# can say) *)
      let predefined = d == Resolve.list_d in
      let path = if predefined then "Pervasives." ^ d.tpath else d.tpath in
      let t = { tok = make_class c loc path arity 0x00100080 (sys c "Object"); arity; fields = []; ftoks = []; ctor = 0 } in
      Hashtbl.replace classes key t;
      constructor c t (object_ctor c);
      let me = own t in
      let parent = type_tok c t me and parent_ctor = ctor_tok c t me in
      (* (each constructor's place in OCaml's order, its classes' ml_order) *)
      let ord = W.method_def c.w t.tok "ml_order" 0x05C6 (instance [] S.I4) in
      List.iteri
        (fun (tag : int) ((cname, k) : string * Scope.cons) ->
          if k.cinline <> [] then refuse loc (cname ^ ", a constructor of an inline record") "1b";
          let params, args, _ = k.ctype in
          let cname' = match cname with "[]" -> "Nil" | "::" -> "Cons" | n -> n in
          let name = if arity > 0 then Printf.sprintf "%s`%d" cname' arity else cname' in
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
          (match k.kind with
           | Const _ ->
               (* (its one value: made once, as OCaml's constant is one
                * word; == of two None true) *)
               let me = own case in
               let f = W.field_def c.w tok "Instance" 0x0016 (at case me) in
               Hashtbl.replace instances tok f;
               let init = W.method_def c.w tok ".cctor" 0x1891 (static [] S.Void) in
               W.set_body c.w init []
                 [| Il.Newobj (ctor_tok c case me); Il.Stsfld (instance_tok c case me); Il.Ret |] []
           | _ -> ());
          let order = match k.kind with Const n -> n | Block n -> 1000000 + n | _ -> tag in
          let m = W.method_def c.w tok "ml_order" 0x00C6 (instance [] S.I4) in
          W.set_body c.w m [] [| Il.Ldc_i4 (Int32.of_int order); Il.Ret |] [];
          structural c case tag (Some (t, ord, order));
          Hashtbl.replace classes (key ^ "|" ^ cname) case)
        (match conses d with Some l -> l | None -> []);
      t

(* a record's type's class and its type arguments *)
let record_at (c : c) (loc : int) (ty : Scope.ty) : tclass * S.t list =
  (* (through abbreviations: Ir's type mem = Asm.mem) *)
  match unabbrev ty with
  | Tconstr (d, args) -> (record c loc d, List.map (arg_type c loc) args)
  | _ -> refuse loc "a record of no record type" "1b"

(* the index of a record's field, by its name *)
let index (t : tclass) (name : string) : int =
  let rec go (i : int) (l : (string * S.t) list) : int =
    match l with (n, _) :: rest -> if n = name then i else go (i + 1) rest | [] -> raise Not_found in
  go 0 t.fields

let field (c : c) (loc : int) (ty : Scope.ty) (name : string) : int =
  let t, args = record_at c loc ty in
  match index t name with
  | i -> field_tok c t args i
  | exception Not_found ->
      refuse loc (Printf.sprintf "%s, a field its record's class has not (%s)" name
                    (String.concat " " (List.map fst t.fields))) "1b"

let field0 (c : c) (loc : int) (ty : Scope.ty) : int =
  let t, args = record_at c loc ty in
  field_tok c t args 0

let record_ctor (c : c) (loc : int) (ty : Scope.ty) : int =
  let t, args = record_at c loc ty in
  ctor_tok c t args

(* a tuple's i-th field at its type, its constructor there *)
let tuple_at (c : c) (loc : int) (ty : Scope.ty) : tclass * S.t list =
  match unabbrev ty with
  | Ttuple ts -> (tuple c loc (List.length ts), List.map (arg_type c loc) ts)
  | _ -> refuse loc "a tuple of no tuple type" "1d"

let tuple_field (c : c) (loc : int) (ty : Scope.ty) (i : int) : int =
  let t, args = tuple_at c loc ty in
  field_tok c t args i

let tuple_ctor (c : c) (loc : int) (ty : Scope.ty) : int =
  let t, args = tuple_at c loc ty in
  ctor_tok c t args

(* a constructor of a variant at the variant's type: its class's token,
 * its constructor, its fields, its arguments' types there *)
(* a type's declaration, through the abbreviations a re-export makes
 * (Option's type 'a t = 'a option = None | Some of 'a): one class
 * for each constructor, the first declaration's *)
let rec canonical (d : Scope.tdecl) : Scope.tdecl =
  match d.tabbrev with Some (Tconstr (d', _)) when d' != d -> canonical d' | _ -> d

(* a constant constructor's one value, at its type's arguments *)
let constant (c : c) (loc : int) (k : Scope.cons) (ty : Scope.ty) : int =
  let _, _, res = k.ctype in
  let d = canonical (decl res) in
  let inst = match unabbrev ty with Tconstr (_, a) -> a | _ -> [] in
  ignore (variant c loc d);
  let t = Hashtbl.find classes (qkey c d ^ "|" ^ k.cname) in
  instance_tok c t (List.map (arg_type c loc) inst)

let case (c : c) (loc : int) (k : Scope.cons) (ty : Scope.ty) : int * int * (int -> int) * Scope.ty list =
  let params, targs, res = k.ctype in
  let d = canonical (decl res) in
  (* (its type's arguments through abbreviations: Relset's hint, a
   * Btree.hint option) *)
  let inst = match unabbrev ty with Tconstr (_, a) -> a | _ -> [] in
  ignore (variant c loc d);
  let t = Hashtbl.find classes (qkey c d ^ "|" ^ k.cname) in
  let args = List.map (arg_type c loc) inst in
  let types = if List.length params = List.length inst then List.map (subst params inst) targs else targs in
  (type_tok c t args, ctor_tok c t args, field_tok c t args, types)

(* a record's fields' types at the record's type, by label *)
let label_type (l : Scope.label) (ty : Scope.ty) : Scope.ty =
  let params, fty, _ = l.ltype in
  match unabbrev ty with Tconstr (_, inst) when List.length params = List.length inst -> subst params inst fty | _ -> fty

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
      let outer = if predefined then None else unit_class c (fst (split c sym)) in
      if not predefined && outer = None then refuse loc ("the exception " ^ sym ^ ", of a unit not compiled with it") "1e";
      let cls, ctor, toks =
        new_class c (if predefined then "Stdlib" else "") name (if predefined then 0x00100001 else 0x00100002) (sys c "Exception") base
          [ Il.Ldstr (W.user_string c.w name) ] fields in
      (match outer with Some o -> W.nest c.w cls o | None -> ());
      Hashtbl.replace c.memo key cls;
      Hashtbl.replace c.memo (key ^ " ctor") ctor;
      List.iteri (fun (i : int) (f : int) -> Hashtbl.replace c.memo (Printf.sprintf "%s.%d" key i) f) toks
    end;
    (Hashtbl.find c.memo key, Hashtbl.find c.memo (key ^ " ctor"), fun (i : int) -> Hashtbl.find c.memo (Printf.sprintf "%s.%d" key i))
  end

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

let type_of (e : Scope.expr) : Scope.ty =
  match Hashtbl.find_opt synthetic e.span with
  | Some t -> t
  | None -> (match Typing.expr_type e with Some t -> t | None -> refuse e.loc "an expression whose type was not kept" "1a")

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

(* a .NET type's token, as newarr, box, ldelem.any take it: System's
 * class for a primitive, a class's own, a TypeSpec for the others *)
let type_token (c : c) (t : S.t) : int =
  match t with
  | S.I8 -> sys c "Int64"
  | S.I4 -> sys c "Int32"
  | S.Bool -> sys c "Boolean"
  | S.R8 -> sys c "Double"
  | S.String -> sys c "String"
  | S.Object -> sys c "Object"
  | S.Class tok -> tok
  | t -> W.type_spec c.w t
