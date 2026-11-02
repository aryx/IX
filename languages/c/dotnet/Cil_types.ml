(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Cil_types.mli *)

open Tree
open Tree_helpers
module S = Signature
module W = Writer

exception Refused of int * string

let refuse (line : int) (what : string) : 'a =
  raise (Refused (line, what ^ ": not in mini-cc's managed C"
                        ^ " (plan_dotnet_languages.md, decision 4)"))

(*****************************************************************************)
(* The assembly's classes and members, each made when first needed *)
(*****************************************************************************)

type strukt = {
  stok : int;
  sctor : int;
  sclone : int;
  fields : (int * typ * int) list;      (* each member: its offset, type, field *)
}

type c = {
  w : W.t;
  runtime : int;                        (* the assembly System.Runtime *)
  console : int;                        (* System.Console, in its own assembly *)
  cls : int;                            (* the program's class *)
  memo : (string, int) Hashtbl.t;       (* what is made, by a name of ours *)
  mutable structs : (typ * strukt) list;
  mutable classes : (typ * int) list;   (* a structure's class, before its fields *)
}

let memo (c : c) (key : string) (make : unit -> int) : int =
  match Hashtbl.find_opt c.memo key with
  | Some x -> x
  | None ->
      let x = make () in
      Hashtbl.replace c.memo key x;
      x

let static (ps : S.t list) (r : S.t) : S.meth =
  { S.has_this = false; generic = 0; vararg = false; ret = r; params = ps }
let instance (ps : S.t list) (r : S.t) : S.meth =
  { (static ps r) with has_this = true }

let sys (c : c) (name : string) : int =
  memo c ("type " ^ name) (fun () ->
      if name = "Console" then c.console
      else
        match String.rindex_opt name '.' with
        | Some i ->
            W.type_ref c.w c.runtime ("System." ^ String.sub name 0 i)
              (String.sub name (i + 1) (String.length name - i - 1))
        | None -> W.type_ref c.w c.runtime "System" name)

(* a member of .NET's library: its class (IO.Stream: System.IO's), name
 * and signature *)
let lib (c : c) (cls : string) (name : string) (m : S.meth) : int =
  memo c (cls ^ "::" ^ name ^ S.encode_method m) (fun () ->
      W.member_ref c.w (sys c cls) name m)

let object_ctor (c : c) : int = lib c "Object" ".ctor" (instance [] S.Void)

(*****************************************************************************)
(* A method's code: the instructions, their labels, the locals *)
(*****************************************************************************)

type code = {
  mutable ops : Il.op list;             (* reversed *)
  mutable n : int;
  labels : (int, int) Hashtbl.t;        (* a label to its instruction *)
  mutable nlabels : int;
  mutable locals : S.t list;            (* reversed *)
  mutable nlocals : int;
}

let new_code () : code =
  { ops = []; n = 0; labels = Hashtbl.create 8; nlabels = 0; locals = [];
    nlocals = 0 }

let emit (k : code) (op : Il.op) : unit =
  k.ops <- op :: k.ops;
  k.n <- k.n + 1

let label (k : code) : int =
  k.nlabels <- k.nlabels + 1;
  k.nlabels

let place (k : code) (l : int) : unit = Hashtbl.replace k.labels l k.n

let local (k : code) (ty : S.t) : int =
  k.locals <- ty :: k.locals;
  k.nlocals <- k.nlocals + 1;
  k.nlocals - 1

(* the labels made instructions' numbers, and the body set *)
let finish (c : c) (k : code) (meth : int) : unit =
  let at (l : int) : int = Hashtbl.find k.labels l in
  let ops =
    Array.of_list
      (List.rev_map
         (fun (op : Il.op) ->
           match op with
           | Il.Br l -> Il.Br (at l)
           | Il.Brfalse l -> Il.Brfalse (at l)
           | Il.Brtrue l -> Il.Brtrue (at l)
           | Il.Bcmp (x, u, l) -> Il.Bcmp (x, u, at l)
           | op -> op)
         k.ops) in
  W.set_body c.w meth (List.rev k.locals) ops []

(* an int32 constant *)
let ldc (k : code) (n : int) : unit = emit k (Il.Ldc_i4 (Int32.of_int n))

(*****************************************************************************)
(* C's types as .NET's *)
(*****************************************************************************)

(* what an array is made of: an array of arrays is one array of their
 * elements (int m[3][4], 12 ints), as C lays it out *)
let rec base (t : typ) : typ = if t.etype = Tarray then base (link t) else t

let count (line : int) (t : typ) : int =
  let b = base t in
  if b.width < 1 then refuse line "an array of an incomplete type"
  else t.width / b.width

(* the Ptr class (a C pointer: an array and an index in it, null for
 * 0), made once; its methods' signatures as its own body names them *)
let ptr_class (c : c) : int = Hashtbl.find c.memo "class Ptr"
let ptr_of (c : c) (t : S.t) : S.t = S.GenericInst (S.Class (ptr_class c), [ t ])
let self (c : c) : S.t = ptr_of c (S.Var 0)

let ptr_member (c : c) (t : S.t) (name : string) (m : S.meth) : int =
  memo c ("Ptr " ^ S.encode_type_spec t ^ " " ^ name) (fun () ->
      W.member_ref c.w (W.type_spec c.w (ptr_of c t)) name m)

let ptr_field (c : c) (t : S.t) (name : string) (ty : S.t) : int =
  memo c ("Ptr field " ^ S.encode_type_spec t ^ " " ^ name) (fun () ->
      W.field_ref c.w (W.type_spec c.w (ptr_of c t)) name ty)

let ptr_ctor (c : c) (t : S.t) : int =
  ptr_member c t ".ctor" (instance [ S.SzArray (S.Var 0); S.I4 ] S.Void)
let ptr_get (c : c) (t : S.t) : int = ptr_member c t "Get" (instance [] (S.Var 0))
let ptr_set (c : c) (t : S.t) : int =
  ptr_member c t "Set" (instance [ S.Var 0 ] S.Void)
let ptr_add (c : c) (t : S.t) : int =
  ptr_member c t "Add" (instance [ S.I4 ] (self c))
let ptr_diff (c : c) (t : S.t) : int =
  ptr_member c t "Diff" (static [ self c; self c ] S.I4)
let ptr_eq (c : c) (t : S.t) : int =
  ptr_member c t "Eq" (static [ self c; self c ] S.I4)
let ptr_array (c : c) (t : S.t) : int = ptr_field c t "a" (S.SzArray (S.Var 0))
let ptr_index (c : c) (t : S.t) : int = ptr_field c t "i" S.I4

(* its class: Get and Set the element, Add an offset, Diff of two, Eq
 * (both null, or the same array and index) *)
let make_ptr_class (c : c) : unit =
  let w = c.w in
  let cls = W.type_def w "" "Ptr`1" 0x00100101 (sys c "Object") in
  W.generic_param w cls 0 "T";
  Hashtbl.replace c.memo "class Ptr" cls;
  ignore (W.field_def w cls "a" 0x0006 (S.SzArray (S.Var 0)));
  ignore (W.field_def w cls "i" 0x0006 S.I4);
  let v = S.Var 0 in
  let a = ptr_array c v and i = ptr_index c v and elt = W.type_spec w v in
  let body (name : string) (flags : int) (m : S.meth) (ops : Il.op list) =
    let meth = W.method_def w cls name flags m in
    W.set_body w meth [] (Array.of_list ops) [] in
  body ".ctor" 0x1886 (instance [ S.SzArray v; S.I4 ] S.Void)
    [ Il.Ldarg 0; Il.Call (object_ctor c); Il.Ldarg 0; Il.Ldarg 1; Il.Stfld a;
      Il.Ldarg 0; Il.Ldarg 2; Il.Stfld i; Il.Ret ];
  body "Get" 0x0086 (instance [] v)
    [ Il.Ldarg 0; Il.Ldfld a; Il.Ldarg 0; Il.Ldfld i; Il.Ldelem_any elt; Il.Ret ];
  body "Set" 0x0086 (instance [ v ] S.Void)
    [ Il.Ldarg 0; Il.Ldfld a; Il.Ldarg 0; Il.Ldfld i; Il.Ldarg 1;
      Il.Stelem_any elt; Il.Ret ];
  body "Add" 0x0086 (instance [ S.I4 ] (self c))
    [ Il.Ldarg 0; Il.Ldfld a; Il.Ldarg 0; Il.Ldfld i; Il.Ldarg 1; Il.Binop Il.Add;
      Il.Newobj (ptr_ctor c v); Il.Ret ];
  body "Diff" 0x0096 (static [ self c; self c ] S.I4)
    [ Il.Ldarg 0; Il.Ldfld i; Il.Ldarg 1; Il.Ldfld i; Il.Binop Il.Sub; Il.Ret ];
  (* (a branch's target an instruction's index: 6, 10, 21) *)
  body "Eq" 0x0096 (static [ self c; self c ] S.I4)
    [ Il.Ldarg 0; Il.Brtrue 6; Il.Ldarg 1; Il.Ldnull; Il.Ceq; Il.Ret;
      Il.Ldarg 1; Il.Brtrue 10; Il.Ldc_i4 0l; Il.Ret;
      Il.Ldarg 0; Il.Ldfld a; Il.Ldarg 1; Il.Ldfld a; Il.Bcmp (Il.Ne, true, 21);
      Il.Ldarg 0; Il.Ldfld i; Il.Ldarg 1; Il.Ldfld i; Il.Ceq; Il.Ret;
      Il.Ldc_i4 0l; Il.Ret ]

(* a .NET type's token: System's class for a primitive, a class's own,
 * a TypeSpec for the others *)
let token_of (c : c) (ty : S.t) : int =
  match ty with
  | S.I1 -> sys c "SByte"
  | S.U1 -> sys c "Byte"
  | S.I2 -> sys c "Int16"
  | S.U2 -> sys c "UInt16"
  | S.I4 -> sys c "Int32"
  | S.U4 -> sys c "UInt32"
  | S.I8 -> sys c "Int64"
  | S.U8 -> sys c "UInt64"
  | S.R4 -> sys c "Single"
  | S.R8 -> sys c "Double"
  | S.Object -> sys c "Object"
  | S.Class tok -> tok
  | ty -> memo c ("spec " ^ S.encode_type_spec ty) (fun () -> W.type_spec c.w ty)

(* a structure's, by its type or its tag (a type copied for a
 * qualifier is the same structure) *)
let same_struct (t : typ) (l : (typ * 'a) list) : 'a option =
  let same (t' : typ) =
    t' == t || (match t.tag, t'.tag with Some a, Some b -> a == b | _ -> false) in
  Option.map snd (List.find_opt (fun ((t', _) : typ * 'a) -> same t') l)

(* a value's type where it is stored: an array's element, a member *)
let rec cts (c : c) (line : int) (t : typ) : S.t =
  match t.etype with
  | Tchar -> S.I1
  | Tuchar -> S.U1
  | Tshort -> S.I2
  | Tushort -> S.U2
  | Tint | Tlong | Tenum -> S.I4
  | Tuint | Tulong -> S.U4
  | Tvlong -> S.I8
  | Tuvlong -> S.U8
  | Tfloat -> S.R4
  | Tdouble -> S.R8
  | Tvoid -> S.Void
  | Tind ->
      let p = link t in
      if p.etype = Tfunc then delegate c line p else ptr_of c (pointee c line p)
  | Tarray -> S.SzArray (cts c line (base t))
  | Tstruct -> S.Class (struct_class c line t)
  | Tunion -> refuse line "a union"
  | Tfunc | Tdot | Told | Txxx -> refuse line ("a value of type " ^ tname t.etype)

(* what a pointer's array holds: void*'s an object *)
and pointee (c : c) (line : int) (p : typ) : S.t =
  let b = base p in
  if b.etype = Tvoid then S.Object else cts c line b

(* a function's pointer: a Func (Action if void) of its parameters and
 * result, each a slot's type *)
and delegate (c : c) (line : int) (f : typ) : S.t =
  let ps = params c line f and r = slot c line (link f) in
  let generic (name : string) (ts : S.t list) =
    let cls = sys c (Printf.sprintf "%s`%d" name (List.length ts)) in
    S.GenericInst (S.Class cls, ts) in
  if r <> S.Void then generic "Func" (ps @ [ r ])
  else if ps = [] then S.Class (sys c "Action")
  else generic "Action" ps

and params (c : c) (line : int) (f : typ) : S.t list =
  let rec go (p : typ option) =
    match p with
    | None -> []
    | Some p when p.etype = Tvoid && p.down = None -> []
    | Some p when p.etype = Tdot || p.etype = Told ->
        refuse line "a function of variable arguments"
    | Some p -> slot c line p :: go p.down in
  go f.down

(* a variable's, a parameter's, a result's: a char or short an int32,
 * as C passes it (an array is its reference) *)
and slot (c : c) (line : int) (t : typ) : S.t =
  match t.etype with
  | Tchar | Tuchar | Tshort | Tushort -> S.I4
  | _ -> cts c line t

(* a structure's class: its token, which its members may name (a
 * Node's next), given before they are made *)
and struct_class (c : c) (line : int) (t : typ) : int =
  match same_struct t c.classes with
  | Some tok -> tok
  | None -> (struct_info c line t).stok

and struct_info (c : c) (line : int) (t : typ) : strukt =
  match same_struct t c.structs with
  | Some s -> s
  | None ->
      let w = c.w in
      let name =
        match t.tag with
        | Some s -> s.name
        | None -> Printf.sprintf "struct%d" (List.length c.classes) in
      let tok = W.type_def w "" name 0x00100101 (sys c "Object") in
      c.classes <- (t, tok) :: c.classes;
      let rec members (m : typ option) =
        match m with
        | None -> []
        | Some m -> (
            match m.tsym with
            | None -> refuse line ("an unnamed member of struct " ^ name)
            | Some s ->
                (m.offset, m, W.field_def w tok s.name 0x0006 (cts c line m))
                :: members m.down) in
      let fields = members t.link in
      let ctor = W.method_def w tok ".ctor" 0x1886 (instance [] S.Void) in
      let clone = W.method_def w tok "Clone" 0x0086 (instance [] (S.Class tok)) in
      let s = { stok = tok; sctor = ctor; sclone = clone; fields } in
      c.structs <- (t, s) :: c.structs;
      (* its constructor makes its arrays and structures *)
      let k = new_code () in
      emit k (Il.Ldarg 0);
      emit k (Il.Call (object_ctor c));
      List.iter
        (fun ((_, m, f) : int * typ * int) ->
          match m.etype with
          | Tarray ->
              emit k (Il.Ldarg 0);
              new_array c k line m (fun () -> ldc k (count line m));
              emit k (Il.Stfld f)
          | Tstruct ->
              emit k (Il.Ldarg 0);
              emit k (Il.Newobj (struct_info c line m).sctor);
              emit k (Il.Stfld f)
          | _ -> ())
        fields;
      emit k Il.Ret;
      finish c k ctor;
      (* its copy: C's assignment of a structure *)
      let k = new_code () in
      let r = local k (S.Class tok) in
      emit k (Il.Newobj ctor);
      emit k (Il.Stloc r);
      List.iter
        (fun ((_, m, f) : int * typ * int) ->
          match m.etype with
          | Tarray ->
              let b = base m in
              let i = local k S.I4 and top = label k and stop = label k in
              ldc k 0;
              emit k (Il.Stloc i);
              place k top;
              emit k (Il.Ldloc i);
              ldc k (count line m);
              emit k (Il.Bcmp (Il.Ge, false, stop));
              emit k (Il.Ldloc r); emit k (Il.Ldfld f); emit k (Il.Ldloc i);
              emit k (Il.Ldarg 0); emit k (Il.Ldfld f); emit k (Il.Ldloc i);
              emit k (Il.Ldelem (load_kind c line b));
              if b.etype = Tstruct then
                emit k (Il.Callvirt (struct_info c line b).sclone);
              emit k (Il.Stelem (store_kind c line b));
              emit k (Il.Ldloc i); ldc k 1; emit k (Il.Binop Il.Add);
              emit k (Il.Stloc i);
              emit k (Il.Br top);
              place k stop
          | _ ->
              emit k (Il.Ldloc r);
              emit k (Il.Ldarg 0);
              emit k (Il.Ldfld f);
              if m.etype = Tstruct then
                emit k (Il.Callvirt (struct_info c line m).sclone);
              emit k (Il.Stfld f))
        fields;
      emit k (Il.Ldloc r);
      emit k Il.Ret;
      finish c k clone;
      s

(* a new array of t's elements, their number pushed by n; a structure's
 * made each *)
and new_array (c : c) (k : code) (line : int) (t : typ) (n : unit -> unit) : unit =
  let b = base t in
  n ();
  emit k (Il.Newarr (type_token c line b));
  if b.etype = Tstruct then begin
    let a = local k (S.SzArray (cts c line b)) and i = local k S.I4 in
    let top = label k and stop = label k in
    emit k (Il.Stloc a);
    ldc k 0;
    emit k (Il.Stloc i);
    place k top;
    emit k (Il.Ldloc i);
    emit k (Il.Ldloc a);
    emit k Il.Ldlen;
    emit k (Il.Conv (Il.K_i4, false, false));
    emit k (Il.Bcmp (Il.Ge, false, stop));
    emit k (Il.Ldloc a); emit k (Il.Ldloc i);
    emit k (Il.Newobj (struct_info c line b).sctor); emit k (Il.Stelem Il.K_ref);
    emit k (Il.Ldloc i); ldc k 1; emit k (Il.Binop Il.Add); emit k (Il.Stloc i);
    emit k (Il.Br top);
    place k stop;
    emit k (Il.Ldloc a)
  end

(* a type's token, as newarr takes it *)
and type_token (c : c) (line : int) (t : typ) : int = token_of c (pointee c line t)

and load_kind (c : c) (line : int) (t : typ) : Il.kind =
  match cts c line t with
  | S.I1 -> Il.K_i1
  | S.U1 -> Il.K_u1
  | S.I2 -> Il.K_i2
  | S.U2 -> Il.K_u2
  | S.I4 -> Il.K_i4
  | S.U4 -> Il.K_u4
  | S.I8 | S.U8 -> Il.K_i8
  | S.R4 -> Il.K_r4
  | S.R8 -> Il.K_r8
  | _ -> Il.K_ref

and store_kind (c : c) (line : int) (t : typ) : Il.kind =
  match load_kind c line t with
  | Il.K_u1 -> Il.K_i1
  | Il.K_u2 -> Il.K_i2
  | Il.K_u4 -> Il.K_i4
  | k -> k

(* a delegate's Invoke and constructor (an object, a method's address) *)
let invoke (c : c) (line : int) (f : typ) : int =
  let d = delegate c line f in
  let n = List.length (params c line f) in
  let r = if slot c line (link f) = S.Void then S.Void else S.Var n in
  memo c ("invoke " ^ S.encode_type_spec d) (fun () ->
      let ps = List.init n (fun (i : int) -> S.Var i) in
      W.member_ref c.w (W.type_spec c.w d) "Invoke" (instance ps r))

let delegate_ctor (c : c) (line : int) (f : typ) : int =
  let d = delegate c line f in
  memo c ("delegate ctor " ^ S.encode_type_spec d) (fun () ->
      let cls = match d with S.Class t -> t | _ -> W.type_spec c.w d in
      W.member_ref c.w cls ".ctor" (instance [ S.Object; S.I ] S.Void))
