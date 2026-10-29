(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Csc_emit.mli *)

module A = Csc_ast
module T = Csc_types
module S = Signature
module W = Writer
module M = Metadata

open Csc_types

(* ------------------------------------------------------------------ *)
(* Tokens: the library's names, the program's rows *)
(* ------------------------------------------------------------------ *)

type ctx = {
  w : W.t;
  memo : (string, int) Hashtbl.t;
}

let memo (c : ctx) (key : string) (make : unit -> int) : int =
  match Hashtbl.find_opt c.memo key with
  | Some x -> x
  | None -> let x = make () in Hashtbl.replace c.memo key x; x

(* the reference assembly a library type is in *)
let assembly (c : ctx) (name : string) : int =
  let a =
    if name = "System.Console" then "System.Console"
    else if String.length name > 27 && String.sub name 0 27 = "System.Collections.Generic." then "System.Collections"
    else "System.Runtime" in
  W.assembly_ref c.w a

let rec cls_token (c : ctx) (k : cls) : int =
  if k.token <> 0 then k.token
  else begin
    let t = match String.rindex_opt k.name '+' with
      | Some i ->
          (* a nested type: a TypeRef whose scope is its outer type's *)
          let outer = match lib_class (String.sub k.name 0 i) with
            | Some o -> cls_token c o | None -> error 0 ("no class " ^ k.name) in
          W.type_ref c.w outer "" (String.sub k.name (i + 1) (String.length k.name - i - 1))
      | None ->
          let ns, n = match String.rindex_opt k.name '.' with
            | Some i -> (String.sub k.name 0 i, String.sub k.name (i + 1) (String.length k.name - i - 1))
            | None -> ("", k.name) in
          W.type_ref c.w (assembly c k.name) ns n in
    k.token <- t;
    t
  end

let rec sig_of (c : ctx) (t : ty) : S.t =
  match t with
  | Void -> S.Void | Bool -> S.Bool | Char -> S.Char | Int -> S.I4 | Long -> S.I8
  | Double -> S.R8 | String -> S.String | Object | Null -> S.Object
  | Array e -> S.SzArray (sig_of c e)
  | Ref e -> S.ByRef (sig_of c e)
  | Var n -> S.Var n
  | MVar n -> S.MVar n
  | Class (k, args) ->
      let base = if k.kind = K_struct then S.ValueType (cls_token c k) else S.Class (cls_token c k) in
      if args = [] then base else S.GenericInst (base, List.map (sig_of c) args)

(* a type as an instruction's operand: newarr, box, castclass *)
let type_token (c : ctx) (t : ty) : int =
  match t with
  | Class (k, []) -> cls_token c k
  | Bool | Char | Int | Long | Double | String | Object ->
      let name = List.assoc t (List.map (fun (n, t) -> (t, n)) primitives) in
      (match lib_class name with Some k -> cls_token c k | None -> error 0 ("no class " ^ name))
  | _ -> memo c ("spec " ^ S.encode_type_spec (sig_of c t)) (fun () -> W.type_spec c.w (sig_of c t))

let meth_sig (c : ctx) (m : meth) : S.meth =
  { S.has_this = not m.mstatic; generic = m.mgeneric; vararg = false;
    ret = sig_of c m.mret; params = List.map (sig_of c) m.mparams }

(* a method's token: the program's MethodDef, or a MemberRef on the
 * class it is called on (a generic instance: a TypeSpec) *)
let meth_token (c : ctx) (on : ty) (m : meth) : int =
  if m.mtoken <> 0 then m.mtoken
  else begin
    let parent = match on with
      | Class (k, args) when k == m.mowner && args <> [] -> type_token c on
      | _ -> cls_token c m.mowner in
    W.member_ref c.w parent m.mname (meth_sig c m)
  end

(* ------------------------------------------------------------------ *)
(* A method's code: instructions and labels, locals, scopes *)
(* ------------------------------------------------------------------ *)

type item = Op of Il.op | Label of int

type m = {
  c : ctx;
  cls : cls;
  meth : meth;
  mutable items : item list;                       (* reversed *)
  mutable nlabels : int;
  mutable locals : S.t list;                       (* reversed *)
  mutable nlocals : int;
  mutable scopes : (string * (int * ty)) list list;
  args : (string * (int * ty)) list;
  mutable loops : (int * int * int) list;          (* break, continue, the trys around *)
  mutable trys : int;
  mutable clauses : (int * int * int * int * int * int) list;   (* kind, labels, class *)
  mutable ret : (int * int) option;                (* a return inside a try: its label, its local *)
}

let emit (m : m) (op : Il.op) : unit = m.items <- Op op :: m.items
let label (m : m) : int = m.nlabels <- m.nlabels + 1; m.nlabels
let place (m : m) (l : int) : unit = m.items <- Label l :: m.items
let local (m : m) (t : ty) : int =
  m.locals <- sig_of m.c t :: m.locals; m.nlocals <- m.nlocals + 1; m.nlocals - 1

(* a name in a method: a local, an argument, or neither *)
type found = Found_local of int * ty | Found_arg of int * ty | Not_found_here

let lookup (m : m) (n : string) : found =
  let rec go l = match l with
    | [] -> (match List.assoc_opt n m.args with Some (i, t) -> Found_arg (i, t) | None -> Not_found_here)
    | s :: rest -> (match List.assoc_opt n s with Some (i, t) -> Found_local (i, t) | None -> go rest) in
  go m.scopes

let declare (m : m) (pos : int) (n : string) (t : ty) : int =
  (match m.scopes with
   | s :: _ when List.mem_assoc n s -> error pos ("the local " ^ n ^ " declared twice")
   | _ -> ());
  let i = local m t in
  (match m.scopes with s :: rest -> m.scopes <- ((n, (i, t)) :: s) :: rest | [] -> ());
  i

let lib_meth (pos : int) (cls : string) (name : string) (args : ty list) : meth * ty =
  match lib_class cls with
  | Some k -> let mt, _ = best pos (cls ^ "::" ^ name) (methods (Class (k, [])) name) args in (mt, Class (k, []))
  | None -> error pos ("no class " ^ cls)

(* ------------------------------------------------------------------ *)
(* Conversions *)
(* ------------------------------------------------------------------ *)

(* the value of type [from] on the stack made one of [to_] *)
let coerce (m : m) (pos : int) (from : ty) (to_ : ty) : unit =
  match convertible from to_ with
  | None -> error pos (Printf.sprintf "a %s where a %s is expected" (show from) (show to_))
  | Some 0 -> ()
  | Some _ ->
      match from, to_ with
      | (Int | Char), Long -> emit m (Il.Conv (Il.K_i8, false, false))
      | (Int | Char | Long), Double -> emit m (Il.Conv (Il.K_r8, false, false))
      | t, Object when is_value t -> emit m (Il.Box (type_token m.c t))
      | _ -> ()

(* the type two operands are computed in (C#'s binary numeric
 * promotions, 7.3.6.2) *)
let promote (a : ty) (b : ty) : ty option =
  match a, b with
  | (Int | Char | Long | Double), (Int | Char | Long | Double) ->
      Some (if a = Double || b = Double then Double else if a = Long || b = Long then Long else Int)
  | _ -> None

(* ------------------------------------------------------------------ *)
(* Expressions *)
(* ------------------------------------------------------------------ *)

(* a type named in an expression: System.Console, int, Shape *)
let rec as_type (m : m) (e : A.expr) : ty option =
  let rec names (e : A.expr) = match e.e with
    | A.Name n -> Some [ n ]
    | A.Member (e, n) -> Option.map (fun l -> l @ [ n ]) (names e)
    | _ -> None in
  match e.e with
  | A.Typed_name t -> Some (resolve e.pos t)
  | A.Name n when lookup m n <> Not_found_here || field (Class (m.cls, [])) n <> None -> None
  | A.Name _ | A.Member _ ->
      (match names e with
       | Some l -> (match resolve e.pos (A.Named (l, [])) with t -> Some t | exception Error _ -> None)
       | None -> None)
  | _ -> None

and this_type (m : m) : ty = Class (m.cls, [])

and expr (m : m) (e : A.expr) : ty =
  match e.e with
  | A.Int n -> emit m (Il.Ldc_i4 n); Int
  | A.Long n -> emit m (Il.Ldc_i8 n); Long
  | A.Double f -> emit m (Il.Ldc_r f); Double
  | A.Str s -> emit m (Il.Ldstr (W.user_string m.c.w s)); String
  | A.Char ch -> emit m (Il.Ldc_i4 (Int32.of_int ch)); Char
  | A.Bool b -> emit m (Il.Ldc_i4 (if b then Int32.one else Int32.zero)); Bool
  | A.Null -> emit m Il.Ldnull; Null
  | A.This | A.Base ->
      if m.meth.mstatic then error e.pos "this in a static method";
      emit m (Il.Ldarg 0); this_type m
  | A.Name n ->
      (match lookup m n with
       | Found_local (i, t) -> emit m (Il.Ldloc i); t
       | Found_arg (i, Ref t) -> emit m (Il.Ldarg i); emit m (ldind m t); t
       | Found_arg (i, t) -> emit m (Il.Ldarg i); t
       | Not_found_here ->
           match field (this_type m) n with
           | Some f -> load_field m e.pos None f
           | None -> (match getter m e.pos (this_type m) n with
               | Some g -> call_with m e.pos (if g.mstatic then None else Some (this_expr m)) (this_type m) g []
               | None -> error e.pos ("no variable " ^ n)))
  | A.Member (target, n) ->
      (match as_type m target with
       | Some t ->
           (match field t n with
            | Some f when f.fstatic -> load_field m e.pos None f
            | _ -> (match getter m e.pos t n with
                | Some g -> call_with m e.pos None t g []
                | None -> error e.pos (Printf.sprintf "%s has no static %s" (show t) n)))
       | None ->
           let t = expr m target in
           (match t, n with
            | Array _, "Length" -> emit m Il.Ldlen; emit m (Il.Conv (Il.K_i4, false, false)); Int
            | _ ->
                match field t n with
                | Some f -> if f.fstatic then (emit m Il.Pop; load_field m e.pos None f)
                  else load_field m e.pos (Some ()) f
                | None ->
                    match getter m e.pos t n with
                    | Some g -> call_on m e.pos t g []
                    | None -> error e.pos (Printf.sprintf "%s has no member %s" (show t) n)))
  | A.Call (f, args) -> call m e.pos f args
  | A.Index (a, i) ->
      let t = expr m a in
      (match t with
       | Array el ->
           expr_to m i Int;
           emit m (ldelem m el); el
       | _ ->
           let g = match getter m e.pos t "Item" with
             | Some g -> g
             | None -> if t = String then fst (lib_meth e.pos "System.String" "get_Chars" [ Int ])
               else error e.pos ("an index of a " ^ show t) in
           call_on m e.pos t g [ i ])
  | A.New (t, args) ->
      let t = resolve e.pos t in
      let ctor, ps = best e.pos ("constructor of " ^ show t) (methods t ".ctor") (List.map (type_of m) args) in
      List.iter2 (fun a p -> expr_to m a p) args ps;
      emit m (Il.Newobj (meth_token m.c t ctor));
      t
  | A.New_array (t, n) ->
      let t = resolve e.pos t in
      expr_to m n Int;
      emit m (Il.Newarr (type_token m.c t));
      Array t
  | A.Array_init (t, elems) ->
      let t = resolve e.pos t in
      emit m (Il.Ldc_i4 (Int32.of_int (List.length elems)));
      emit m (Il.Newarr (type_token m.c t));
      List.iteri (fun i x ->
          emit m Il.Dup; emit m (Il.Ldc_i4 (Int32.of_int i));
          expr_to m x t; emit m (stelem m t)) elems;
      Array t
  | A.Unary ("-", x) ->
      let t = expr m x in
      (match promote t t with
       | Some p -> coerce m e.pos t p; emit m Il.Neg; p
       | None -> error e.pos ("- of a " ^ show t))
  | A.Unary (_, x) -> expr_to m x Bool; emit m (Il.Ldc_i4 Int32.zero); emit m Il.Ceq; Bool
  | A.Binary (("&&" | "||") as o, a, b) ->
      let out = label m and short = label m in
      expr_to m a Bool;
      emit m (if o = "&&" then Il.Brfalse short else Il.Brtrue short);
      expr_to m b Bool;
      emit m (Il.Br out);
      place m short;
      emit m (Il.Ldc_i4 (if o = "&&" then Int32.zero else Int32.one));
      place m out;
      Bool
  | A.Binary (o, a, b) -> binary m e.pos o a b
  | A.Assign (o, place_e, value) -> assign m e.pos o place_e value true
  | A.Incr (up, prefix, x) -> step m e.pos up prefix x true
  | A.Cast (t, x) ->
      let t = resolve e.pos t in
      let from = expr m x in
      cast m e.pos from t;
      t
  | A.Is (x, t) ->
      let t = resolve e.pos t in
      let from = expr m x in
      if is_value from then emit m (Il.Box (type_token m.c from));
      emit m (Il.Isinst (type_token m.c t));
      emit m Il.Ldnull; emit m (Il.Cgt true);
      Bool
  | A.Cond (c, a, b) ->
      let ta = type_of m a and tb = type_of m b in
      let t = if convertible ta tb <> None then tb else ta in
      let other = label m and out = label m in
      expr_to m c Bool;
      emit m (Il.Brfalse other);
      expr_to m a t; emit m (Il.Br out);
      place m other;
      expr_to m b t;
      place m out;
      t
  | A.Out x ->
      (match x.e with
       | A.Name n ->
           (match lookup m n with
            | Found_local (i, t) -> emit m (Il.Ldloca i); Ref t
            | Found_arg (i, (Ref _ as t)) -> emit m (Il.Ldarg i); t
            | Found_arg (i, t) -> emit m (Il.Ldarga i); Ref t
            | Not_found_here -> error x.pos ("out of what is not a local: " ^ n))
       | _ -> error x.pos "out of what is not a local")
  | A.Typed_name _ -> error e.pos "a type where a value is expected"

(* its type, without its code: the code made and thrown away *)
and type_of (m : m) (e : A.expr) : ty =
  let items = m.items and locals = m.locals and n = m.nlocals and l = m.nlabels in
  let t = expr m e in
  (* (the labels made stay made: their numbers are not reused) *)
  m.items <- items; m.locals <- locals; m.nlocals <- n;
  ignore l;
  t

and expr_to (m : m) (e : A.expr) (t : ty) : unit =
  let from = expr m e in
  coerce m e.pos from t

and this_expr (_m : m) : A.expr = { A.e = A.This; pos = 0 }

and ldelem (m : m) (t : ty) : Il.op =
  match t with
  | Int -> Il.Ldelem Il.K_i4 | Bool -> Il.Ldelem Il.K_u1 | Char -> Il.Ldelem Il.K_u2
  | Long -> Il.Ldelem Il.K_i8 | Double -> Il.Ldelem Il.K_r8
  | t when is_value t -> Il.Ldelem_any (type_token m.c t)
  | _ -> Il.Ldelem Il.K_ref

and stelem (m : m) (t : ty) : Il.op =
  match t with
  | Int -> Il.Stelem Il.K_i4 | Bool -> Il.Stelem Il.K_i1 | Char -> Il.Stelem Il.K_i2
  | Long -> Il.Stelem Il.K_i8 | Double -> Il.Stelem Il.K_r8
  | t when is_value t -> Il.Stelem_any (type_token m.c t)
  | _ -> Il.Stelem Il.K_ref

and ldind (m : m) (t : ty) : Il.op =
  match t with
  | Int -> Il.Ldind Il.K_i4 | Bool -> Il.Ldind Il.K_u1 | Char -> Il.Ldind Il.K_u2
  | Long -> Il.Ldind Il.K_i8 | Double -> Il.Ldind Il.K_r8
  | t when is_value t -> Il.Ldobj (type_token m.c t)
  | _ -> Il.Ldind Il.K_ref

and stind (m : m) (t : ty) : Il.op =
  match t with
  | Int -> Il.Stind Il.K_i4 | Bool -> Il.Stind Il.K_i1 | Char -> Il.Stind Il.K_i2
  | Long -> Il.Stind Il.K_i8 | Double -> Il.Stind Il.K_r8
  | t when is_value t -> Il.Stobj (type_token m.c t)
  | _ -> Il.Stind Il.K_ref

and load_field (m : m) (pos : int) (on_stack : unit option) (f : field) : ty =
  if f.fstatic then emit m (Il.Ldsfld f.ftoken)
  else begin
    if on_stack = None then begin
      if m.meth.mstatic then error pos ("the field " ^ f.fname ^ " in a static method");
      emit m (Il.Ldarg 0)
    end;
    emit m (Il.Ldfld f.ftoken)
  end;
  f.ftype

and getter (_m : m) (_pos : int) (t : ty) (n : string) : meth option =
  match methods t ("get_" ^ n) with
  | (g, _) :: _ when g.mparams = [] || n = "Item" -> Some g
  | _ -> None

(* a call: f(args), x.f(args), T.f(args), base.f(args) *)
and call (m : m) (pos : int) (f : A.expr) (args : A.expr list) : ty =
  let types = List.map (type_of m) args in
  match f.e with
  | A.Name n ->
      let mt, _ = best pos n (methods (this_type m) n) types in
      call_with m pos (if mt.mstatic then None else Some (this_expr m)) (this_type m) mt args
  | A.Member ({ e = A.Base; _ }, n) ->
      let parent = match m.cls.parent with Some p -> p | None -> Object in
      let mt, ps = best pos n (methods parent n) types in
      emit m (Il.Ldarg 0);
      List.iter2 (fun a p -> expr_to m a p) args ps;
      emit m (Il.Call (meth_token m.c parent mt));
      mt.mret
  | A.Member (target, n) ->
      (match as_type m target with
       | Some t ->
           let mt, _ = best pos (show t ^ "." ^ n) (List.filter (fun (x, _) -> x.mstatic) (methods t n)) types in
           call_with m pos None t mt args
       | None ->
           let t = type_of m target in
           let mt, _ = best pos (show t ^ "." ^ n) (methods t n) types in
           if mt.mstatic then error pos (n ^ " is static: called on its class");
           call_with m pos (Some target) t mt args)
  | _ -> error pos "a call of what is not a method"

(* a method called, `this` the target's value (a value type's: its
 * address, by a local) *)
and call_with (m : m) (pos : int) (target : A.expr option) (t : ty) (mt : meth) (args : A.expr list) : ty =
  (match target with
   | None -> ()
   | Some x ->
       let tt = expr m x in
       if is_value tt then begin
         let tmp = local m tt in
         emit m (Il.Stloc tmp); emit m (Il.Ldloca tmp)
       end);
  let ps = List.map (subst (match t with Class (_, a) -> a | _ -> []) []) mt.mparams in
  List.iter2 (fun a p -> expr_to m a p) args ps;
  let tok = meth_token m.c t mt in
  emit m (if mt.mstatic || is_value t then Il.Call tok else Il.Callvirt tok);
  ignore pos;
  subst (match t with Class (_, a) -> a | _ -> []) [] mt.mret

(* the target already on the stack *)
and call_on (m : m) (pos : int) (t : ty) (mt : meth) (args : A.expr list) : ty =
  if is_value t then begin
    let tmp = local m t in
    emit m (Il.Stloc tmp); emit m (Il.Ldloca tmp)
  end;
  let ps = List.map (subst (match t with Class (_, a) -> a | _ -> []) []) mt.mparams in
  if List.length ps <> List.length args then error pos (mt.mname ^ ": the arguments' count");
  List.iter2 (fun a p -> expr_to m a p) args ps;
  let tok = meth_token m.c t mt in
  emit m (if is_value t then Il.Call tok else Il.Callvirt tok);
  subst (match t with Class (_, a) -> a | _ -> []) [] mt.mret

and binary (m : m) (pos : int) (o : string) (a : A.expr) (b : A.expr) : ty =
  let ta = type_of m a and tb = type_of m b in
  match o with
  | "+" when ta = String || tb = String ->
      (* String.Concat: of two strings, or of two objects (a value boxed) *)
      if ta = String && tb = String then begin
        expr m a |> ignore; expr m b |> ignore;
        let c, on = lib_meth pos "System.String" "Concat" [ String; String ] in
        emit m (Il.Call (meth_token m.c on c))
      end else begin
        expr_to m a Object; expr_to m b Object;
        let c, on = lib_meth pos "System.String" "Concat" [ Object; Object ] in
        emit m (Il.Call (meth_token m.c on c))
      end;
      String
  | ("==" | "!=") when ta = String && tb <> Null || tb = String && ta <> Null ->
      expr_to m a String; expr_to m b String;
      let c, on = lib_meth pos "System.String" (if o = "==" then "op_Equality" else "op_Inequality") [ String; String ] in
      emit m (Il.Call (meth_token m.c on c));
      Bool
  | "==" | "!=" | "<" | ">" | "<=" | ">=" ->
      let t = match promote ta tb with
        | Some t -> t
        | None ->
            if (ta = Bool && tb = Bool) || (not (is_value ta) && not (is_value tb)) then Object
            else error pos (Printf.sprintf "%s %s %s" (show ta) o (show tb)) in
      if t = Object then (expr m a |> ignore; expr m b |> ignore)
      else (expr_to m a t; expr_to m b t);
      let negate () = emit m (Il.Ldc_i4 Int32.zero); emit m Il.Ceq in
      (match o with
       | "==" -> emit m Il.Ceq
       | "!=" -> emit m Il.Ceq; negate ()
       | "<" -> emit m (Il.Clt false)
       | ">" -> emit m (Il.Cgt false)
       | "<=" -> emit m (Il.Cgt (t = Double)); negate ()
       | _ -> emit m (Il.Clt (t = Double)); negate ());
      Bool
  | _ ->
      match promote ta tb with
      | Some t ->
          expr_to m a t; expr_to m b t;
          emit m (Il.Binop (match o with
              | "+" -> Il.Add | "-" -> Il.Sub | "*" -> Il.Mul | "/" -> Il.Div | "%" -> Il.Rem
              | _ -> error pos ("an operator " ^ o)));
          t
      | None -> error pos (Printf.sprintf "%s %s %s" (show ta) o (show tb))

and cast (m : m) (pos : int) (from : ty) (t : ty) : unit =
  match from, t with
  | _ when same from t -> ()
  | (Int | Char | Long | Double), (Int | Char | Long | Double) ->
      emit m (Il.Conv ((match t with Int -> Il.K_i4 | Char -> Il.K_u2 | Long -> Il.K_i8 | _ -> Il.K_r8), false, false))
  | _, _ when convertible from t <> None -> coerce m pos from t
  | (Object | Class _), t when is_value t -> emit m (Il.Unbox_any (type_token m.c t))
  | _, _ when not (is_value from) && not (is_value t) -> emit m (Il.Castclass (type_token m.c t))
  | _ -> error pos (Printf.sprintf "no cast from %s to %s" (show from) (show t))

(* ------------------------------------------------------------------ *)
(* Places: what can be assigned *)
(* ------------------------------------------------------------------ *)

and target (m : m) (e : A.expr) : (unit -> unit) * (unit -> unit) * ty =
  (* (what it needs computed first, kept in locals; then how to load it,
   * how to store the value of a local) *)
  let store_with f = f in
  match e.e with
  | A.Name n ->
      (match lookup m n with
       | Found_local (i, t) -> ((fun () -> emit m (Il.Ldloc i)), store_with (fun () -> emit m (Il.Stloc i)), t)
       | Found_arg (i, Ref t) ->
           let value = local m t in
           ((fun () -> emit m (Il.Ldarg i); emit m (ldind m t)),
            (fun () -> emit m (Il.Stloc value); emit m (Il.Ldarg i); emit m (Il.Ldloc value); emit m (stind m t)),
            t)
       | Found_arg (i, t) -> ((fun () -> emit m (Il.Ldarg i)), (fun () -> emit m (Il.Starg i)), t)
       | Not_found_here ->
           match field (this_type m) n with
           | Some f when f.fstatic ->
               ((fun () -> emit m (Il.Ldsfld f.ftoken)), (fun () -> emit m (Il.Stsfld f.ftoken)), f.ftype)
           | Some f -> field_place m (fun () -> emit m (Il.Ldarg 0)) f
           | None -> error e.pos ("no variable " ^ n))
  | A.Member (x, n) ->
      (match as_type m x with
       | Some t -> (match field t n with
           | Some f when f.fstatic ->
               ((fun () -> emit m (Il.Ldsfld f.ftoken)), (fun () -> emit m (Il.Stsfld f.ftoken)), f.ftype)
           | _ -> error e.pos (show t ^ " has no static field " ^ n))
       | None ->
           let t = expr m x in
           let tmp = local m t in
           emit m (Il.Stloc tmp);
           match field t n with
           | Some f -> field_place m (fun () -> emit m (Il.Ldloc tmp)) f
           | None -> error e.pos (show t ^ " has no field " ^ n))
  | A.Index (a, i) ->
      let t = expr m a in
      let ta = local m t in
      emit m (Il.Stloc ta);
      (match t with
       | Array el ->
           expr_to m i Int;
           let ti = local m Int in
           emit m (Il.Stloc ti);
           let value = local m el in
           ((fun () -> emit m (Il.Ldloc ta); emit m (Il.Ldloc ti); emit m (ldelem m el)),
            (fun () -> emit m (Il.Stloc value); emit m (Il.Ldloc ta); emit m (Il.Ldloc ti);
              emit m (Il.Ldloc value); emit m (stelem m el)),
            el)
       | _ ->
           let g = match getter m e.pos t "Item" with Some g -> g | None -> error e.pos ("an index of " ^ show t) in
           let s = match methods t "set_Item" with (s, _) :: _ -> s | [] -> error e.pos ("no set_Item in " ^ show t) in
           let args = match t with Class (_, a) -> a | _ -> [] in
           let kt = subst args [] (List.hd g.mparams) and vt = subst args [] g.mret in
           expr_to m i kt;
           let ti = local m kt in
           emit m (Il.Stloc ti);
           let value = local m vt in
           ((fun () -> emit m (Il.Ldloc ta); emit m (Il.Ldloc ti); emit m (Il.Callvirt (meth_token m.c t g))),
            (fun () -> emit m (Il.Stloc value); emit m (Il.Ldloc ta); emit m (Il.Ldloc ti);
              emit m (Il.Ldloc value); emit m (Il.Callvirt (meth_token m.c t s))),
            vt))
  | _ -> error e.pos "this cannot be assigned"

and field_place (m : m) (obj : unit -> unit) (f : field) : (unit -> unit) * (unit -> unit) * ty =
  let value = local m f.ftype in
  ((fun () -> obj (); emit m (Il.Ldfld f.ftoken)),
   (fun () -> emit m (Il.Stloc value); obj (); emit m (Il.Ldloc value); emit m (Il.Stfld f.ftoken)),
   f.ftype)

(* x = v, x += v: the value, if [want], left on the stack *)
and assign (m : m) (pos : int) (o : string) (x : A.expr) (v : A.expr) (want : bool) : ty =
  let load, store, t = target m x in
  if o = "=" then expr_to m v t
  else begin
    let bin = String.sub o 0 1 in
    let tv = binary_on m pos bin load t v in
    cast m pos tv t
  end;
  if want then emit m Il.Dup;
  store ();
  if want then t else Void

(* load, op, v: what x op= v computes *)
and binary_on (m : m) (pos : int) (o : string) (load : unit -> unit) (t : ty) (v : A.expr) : ty =
  let tv = type_of m v in
  if o = "+" && (t = String || tv = String) then begin
    load (); coerce m pos t Object; expr_to m v Object;
    let c, on = lib_meth pos "System.String" "Concat" [ Object; Object ] in
    emit m (Il.Call (meth_token m.c on c));
    String
  end else
    match promote t tv with
    | Some p ->
        load (); coerce m pos t p; expr_to m v p;
        emit m (Il.Binop (match o with "+" -> Il.Add | "-" -> Il.Sub | "*" -> Il.Mul | "/" -> Il.Div | _ -> Il.Rem));
        p
    | None -> error pos (Printf.sprintf "%s %s= %s" (show t) o (show tv))

and step (m : m) (pos : int) (up : bool) (prefix : bool) (x : A.expr) (want : bool) : ty =
  let load, store, t = target m x in
  load ();
  if want && not prefix then emit m Il.Dup;
  emit m (Il.Ldc_i4 Int32.one);
  if t = Long then emit m (Il.Conv (Il.K_i8, false, false));
  emit m (Il.Binop (if up then Il.Add else Il.Sub));
  (match t with Char -> emit m (Il.Conv (Il.K_u2, false, false)) | Int | Long -> () | _ -> error pos ("++ of a " ^ show t));
  if want && prefix then emit m Il.Dup;
  store ();
  if want then t else Void

(* ------------------------------------------------------------------ *)
(* Statements *)
(* ------------------------------------------------------------------ *)

let rec stmt (m : m) (s : A.stmt) : unit =
  match s.s with
  | A.Empty -> ()
  | A.Block l ->
      m.scopes <- [] :: m.scopes;
      List.iter (stmt m) l;
      m.scopes <- List.tl m.scopes
  | A.Local (t, vars) ->
      let t = resolve s.spos t in
      List.iter (fun (n, init) ->
          let i = declare m s.spos n t in
          match init with
          | Some e -> expr_to m e t; emit m (Il.Stloc i)
          | None -> ()) vars
  | A.Expr e ->
      (match e.e with
       | A.Assign (o, x, v) -> ignore (assign m e.pos o x v false)
       | A.Incr (up, prefix, x) -> ignore (step m e.pos up prefix x false)
       | _ -> if expr m e <> Void then emit m Il.Pop)
  | A.If (c, t, f) ->
      let other = label m and out = label m in
      expr_to m c Bool;
      emit m (Il.Brfalse other);
      stmt m t;
      emit m (Il.Br out);
      place m other;
      (match f with Some f -> stmt m f | None -> ());
      place m out
  | A.While (c, body) ->
      let test = label m and out = label m in
      place m test;
      expr_to m c Bool;
      emit m (Il.Brfalse out);
      loop m out test body;
      emit m (Il.Br test);
      place m out
  | A.Do (body, c) ->
      let top = label m and test = label m and out = label m in
      place m top;
      loop m out test body;
      place m test;
      expr_to m c Bool;
      emit m (Il.Brtrue top);
      place m out
  | A.For (init, c, step, body) ->
      m.scopes <- [] :: m.scopes;
      List.iter (stmt m) init;
      let test = label m and next = label m and out = label m in
      place m test;
      (match c with Some c -> expr_to m c Bool; emit m (Il.Brfalse out) | None -> ());
      loop m out next body;
      place m next;
      List.iter (fun e -> stmt m { A.s = A.Expr e; spos = s.spos }) step;
      emit m (Il.Br test);
      place m out;
      m.scopes <- List.tl m.scopes
  | A.Foreach (t, n, coll, body) ->
      let t = resolve s.spos t in
      m.scopes <- [] :: m.scopes;
      let ct = expr m coll in
      let test = label m and next = label m and out = label m in
      (match ct with
       | Array el ->
           (* for (i = 0; i < a.Length; i++) { T n = a[i]; body } *)
           let a = local m ct and i = local m Int in
           emit m (Il.Stloc a);
           emit m (Il.Ldc_i4 Int32.zero); emit m (Il.Stloc i);
           place m test;
           emit m (Il.Ldloc i); emit m (Il.Ldloc a); emit m Il.Ldlen; emit m (Il.Conv (Il.K_i4, false, false));
           emit m (Il.Bcmp (Il.Ge, false, out));
           let v = declare m s.spos n t in
           emit m (Il.Ldloc a); emit m (Il.Ldloc i); emit m (ldelem m el);
           coerce m s.spos el t; emit m (Il.Stloc v);
           loop m out next body;
           place m next;
           emit m (Il.Ldloc i); emit m (Il.Ldc_i4 Int32.one); emit m (Il.Binop Il.Add); emit m (Il.Stloc i);
           emit m (Il.Br test);
           place m out
       | _ ->
           (* its enumerator, a struct: MoveNext, Current *)
           let ge = match methods ct "GetEnumerator" with (g, _) :: _ -> g | [] -> error s.spos ("foreach over a " ^ show ct) in
           let et = call_on m s.spos ct ge [] in
           let en = local m et in
           emit m (Il.Stloc en);
           let mn = match methods et "MoveNext" with (x, _) :: _ -> x | [] -> error s.spos "no MoveNext" in
           let cur = match methods et "get_Current" with (x, _) :: _ -> x | [] -> error s.spos "no Current" in
           let address () = emit m (if is_value et then Il.Ldloca en else Il.Ldloc en) in
           let invoke x = emit m (if is_value et then Il.Call (meth_token m.c et x) else Il.Callvirt (meth_token m.c et x)) in
           place m test;
           address (); invoke mn;
           emit m (Il.Brfalse out);
           let v = declare m s.spos n t in
           address (); invoke cur;
           coerce m s.spos (subst (match et with Class (_, a) -> a | _ -> []) [] cur.mret) t;
           emit m (Il.Stloc v);
           loop m out test body;
           place m next;
           emit m (Il.Br test);
           place m out);
      m.scopes <- List.tl m.scopes
  | A.Return e ->
      (match e with Some e -> expr_to m e m.meth.mret | None -> ());
      if m.trys > 0 then begin
        let l, v = match m.ret with
          | Some r -> r
          | None -> let r = (label m, if m.meth.mret = Void then -1 else local m m.meth.mret) in m.ret <- Some r; r in
        if v >= 0 then emit m (Il.Stloc v);
        emit m (Il.Leave l)
      end else emit m Il.Ret
  | A.Break ->
      (match m.loops with
       | (out, _, trys) :: _ -> emit m (if m.trys > trys then Il.Leave out else Il.Br out)
       | [] -> error s.spos "a break outside a loop")
  | A.Continue ->
      (match m.loops with
       | (_, next, trys) :: _ -> emit m (if m.trys > trys then Il.Leave next else Il.Br next)
       | [] -> error s.spos "a continue outside a loop")
  | A.Throw (Some e) -> ignore (expr m e); emit m Il.Throw
  | A.Throw None -> emit m Il.Rethrow
  | A.Try (body, catches, fin) ->
      let out = label m and start = label m and inner_end = label m in
      m.trys <- m.trys + 1;
      place m start;
      stmt m body;
      emit m (Il.Leave out);
      let starts = List.map (fun _ -> label m) catches in
      List.iteri (fun i (t, n, h) ->
          let hs = List.nth starts i in
          place m hs;
          let t = resolve s.spos t in
          m.scopes <- [] :: m.scopes;
          (match n with
           | Some n -> let v = declare m s.spos n t in emit m (Il.Stloc v)
           | None -> emit m Il.Pop);
          stmt m h;
          m.scopes <- List.tl m.scopes;
          emit m (Il.Leave out);
          let stop = if i + 1 < List.length starts then List.nth starts (i + 1) else inner_end in
          m.clauses <- (0, start, List.hd starts, hs, stop, type_token m.c t) :: m.clauses) catches;
      place m inner_end;
      (match fin with
       | Some f ->
           let fs = inner_end and fe = label m in
           stmt m f;
           emit m Il.Endfinally;
           place m fe;
           m.clauses <- (2, start, fs, fs, fe, 0) :: m.clauses
       | None -> ());
      m.trys <- m.trys - 1;
      place m out

and loop (m : m) (out : int) (next : int) (body : A.stmt) : unit =
  m.loops <- (out, next, m.trys) :: m.loops;
  stmt m body;
  m.loops <- List.tl m.loops

(* the method's code to the writer: labels to indexes *)
let finish (m : m) : unit =
  let at = Hashtbl.create 16 in
  let n = ref 0 in
  let ops = List.rev m.items in
  List.iter (fun it -> match it with Op _ -> incr n | Label l -> Hashtbl.replace at l !n) ops;
  let pos l = Hashtbl.find at l in
  let code = Array.of_list (List.filter_map (fun it -> match it with
      | Op (Il.Br l) -> Some (Il.Br (pos l)) | Op (Il.Brfalse l) -> Some (Il.Brfalse (pos l))
      | Op (Il.Brtrue l) -> Some (Il.Brtrue (pos l)) | Op (Il.Bcmp (x, u, l)) -> Some (Il.Bcmp (x, u, pos l))
      | Op (Il.Leave l) -> Some (Il.Leave (pos l))
      | Op op -> Some op | Label _ -> None) ops) in
  (* the clauses, innermost first: in the order made, a nested try's
   * before its outer's, as ECMA asks *)
  let clauses = List.rev_map (fun (kind, ts, te, hs, he, cls) ->
      { W.kind; try_start = pos ts; try_end = pos te; handler_start = pos hs;
        handler_end = pos he; catch = cls }) m.clauses in
  W.set_body m.c.w m.meth.mtoken (List.rev m.locals) code clauses

(* ------------------------------------------------------------------ *)
(* The classes *)
(* ------------------------------------------------------------------ *)

let new_m (c : ctx) (k : cls) (mt : meth) : m =
  let first = if mt.mstatic then 0 else 1 in
  { c; cls = k; meth = mt; items = []; nlabels = 0; locals = []; nlocals = 0; scopes = [ [] ];
    args = List.mapi (fun i (n, t) -> (n, (i + first, t))) (List.combine mt.pnames mt.mparams);
    loops = []; trys = 0; clauses = []; ret = None }

(* a method's body; a constructor's: its fields' initial values, its
 * parent's constructor, then its own *)
let body (c : ctx) (k : cls) (mt : meth) : unit =
  let m = new_m c k mt in
  if mt.mname = ".cctor" then
    List.iter (fun f -> match f.finit with
        | Some e when f.fstatic -> expr_to m e f.ftype; emit m (Il.Stsfld f.ftoken)
        | _ -> ()) k.fields
  else if mt.mname = ".ctor" then begin
    (match mt.init with
     | Some (false, _) -> ()
     | _ ->
         List.iter (fun f -> match f.finit with
             | Some e when not f.fstatic -> emit m (Il.Ldarg 0); expr_to m e f.ftype; emit m (Il.Stfld f.ftoken)
             | _ -> ()) k.fields);
    let parent = match k.parent with Some p -> p | None -> Object in
    let on, args = match mt.init with
      | Some (true, args) -> (parent, args)
      | None -> (parent, [])
      | Some (false, args) -> (Class (k, []), args) in
    let types = List.map (type_of m) args in
    let ctor, ps = best 0 ("constructor of " ^ show on) (methods on ".ctor") types in
    emit m (Il.Ldarg 0);
    List.iter2 (fun a p -> expr_to m a p) args ps;
    emit m (Il.Call (meth_token c on ctor))
  end;
  (match mt.body with Some b -> stmt m b | None -> ());
  (match m.ret with
   | Some (l, v) -> place m l; if v >= 0 then emit m (Il.Ldloc v); emit m Il.Ret
   | None -> if mt.mret = Void then emit m Il.Ret);
  finish m
