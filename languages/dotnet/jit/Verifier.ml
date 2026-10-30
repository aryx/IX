(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Verifier.mli *)

module M = Metadata
module S = Signature

type vt =
  | Int32
  | Int64
  | Native
  | Float
  | Obj of S.t option
  | Ptr of S.t
  | Value of S.t
  | Gen of S.t

exception Bad of string

let bad (msg : string) = raise (Bad msg)

let show (v : vt) : string =
  match v with
  | Int32 -> "int32" | Int64 -> "int64" | Native -> "native int" | Float -> "F"
  | Obj None -> "null" | Obj (Some t) -> S.show (fun _ -> "class") t
  | Ptr t -> S.show (fun _ -> "class") t ^ "&"
  | Value _ -> "a value type"
  | Gen t -> S.show (fun _ -> "class") t

let kind (v : vt) : string =
  match v with
  | Int32 -> "an int32" | Int64 -> "an int64" | Native -> "a native int" | Float -> "a float"
  | Obj _ -> "a reference" | Ptr _ -> "a managed pointer" | Value _ -> "a value type"
  | Gen _ -> "a type parameter's value"

(* ------------------------------------------------------------------ *)
(* Types: a signature's, as the stack holds it *)
(* ------------------------------------------------------------------ *)

(* is a token's type a value type? a TypeDef by what it extends, a
 * TypeRef by the library's knowledge (mini-dotnet's System) *)
let primitive_of_name (n : string) : vt option =
  match n with
  | "System.Boolean" | "System.Char" | "System.SByte" | "System.Byte" | "System.Int16"
  | "System.UInt16" | "System.Int32" | "System.UInt32" -> Some Int32
  | "System.Int64" | "System.UInt64" -> Some Int64
  | "System.IntPtr" | "System.UIntPtr" -> Some Native
  | "System.Single" | "System.Double" -> Some Float
  | _ -> None

let rec type_name (img : Image.t) (tok : int) : string =
  let row = M.token_row tok in
  let dotted ns n = if ns = "" then n else ns ^ "." ^ n in
  match M.token_table tok with
  | t when t = M.t_type_def ->
      dotted (Image.string img (Image.get img t row "TypeNamespace")) (Image.string img (Image.get img t row "TypeName"))
  | t when t = M.t_type_ref ->
      let st, sr = Image.decode M.resolution_scope (Image.get img t row "ResolutionScope") in
      let n = dotted (Image.string img (Image.get img t row "TypeNamespace")) (Image.string img (Image.get img t row "TypeName")) in
      if st = M.t_type_ref then type_name img (M.token st sr) ^ "+" ^ n else n
  | _ -> ""

(* an enum's underlying type: its instance field value__ *)
let enum_underlying (img : Image.t) (row : int) : vt =
  let ff, fl = Image.range img M.t_type_def row "FieldList" M.t_field in
  let rec go f =
    if f > fl then Int32
    else if Image.get img M.t_field f "Flags" land 0x10 = 0 then
      (match S.field (Image.blob img (Image.get img M.t_field f "Signature")) with
       | S.I8 | S.U8 -> Int64 | S.I | S.U -> Native | _ -> Int32)
    else go (f + 1) in
  go ff

let rec of_sig (img : Image.t) (t : S.t) : vt option =
  match t with
  | S.Void -> None
  | S.Bool | S.Char | S.I1 | S.U1 | S.I2 | S.U2 | S.I4 | S.U4 -> Some Int32
  | S.I8 | S.U8 -> Some Int64
  | S.I | S.U | S.FnPtr _ | S.Ptr _ -> Some Native
  | S.R4 | S.R8 -> Some Float
  | S.String | S.Object | S.Class _ | S.SzArray _ | S.Array _ -> Some (Obj (Some t))
  | S.GenericInst (S.Class _, _) -> Some (Obj (Some t))
  | S.GenericInst _ -> Some (Value t)
  | S.ByRef e -> Some (Ptr e)
  | S.Var _ | S.MVar _ -> Some (Gen t)
  | S.TypedRef -> Some (Value t)
  | S.ValueType tok -> Some (value_token img tok)

(* a value type named by its token: a primitive, an enum, a struct *)
and value_token (img : Image.t) (tok : int) : vt =
  match primitive_of_name (type_name img tok) with
  | Some v -> v
  | None ->
      if M.token_table tok = M.t_type_def then
        let row = M.token_row tok in
        let et, er = Image.decode M.type_def_or_ref (Image.get img M.t_type_def row "Extends") in
        if et >= 0 && type_name img (M.token et er) = "System.Enum" then enum_underlying img row
        else Value (S.ValueType tok)
      else Value (S.ValueType tok)

(* a token in an instruction (newarr T, box T): its signature *)
let token_sig (img : Image.t) (tok : int) : S.t =
  match M.token_table tok with
  | t when t = M.t_type_spec ->
      S.type_spec (Image.blob img (Image.get img t (M.token_row tok) "Signature"))
  | t when t = M.t_type_def ->
      let row = M.token_row tok in
      let et, er = Image.decode M.type_def_or_ref (Image.get img t row "Extends") in
      let parent = if et >= 0 then type_name img (M.token et er) else "" in
      if (parent = "System.ValueType" || parent = "System.Enum") && type_name img tok <> "System.Enum"
      then S.ValueType tok else S.Class tok
  | t when t = M.t_type_ref ->
      let n = type_name img tok in
      (match primitive_of_name n with
       | Some _ -> S.ValueType tok
       | None -> match Hashtbl.find_opt Library.specs n with
         | Some sp when sp.skind = Value.Struct || sp.skind = Value.Enum -> S.ValueType tok
         | _ -> if n = "System.String" then S.String else if n = "System.Object" then S.Object else S.Class tok)
  | _ -> S.Object

let token_vt (img : Image.t) (tok : int) : vt =
  match of_sig img (token_sig img tok) with Some v -> v | None -> bad "a type void"

(* the signature a call names: a MethodDef's, a MemberRef's (its class's
 * arguments put in for !0, when it is called on an instance of a
 * generic class), a MethodSpec's (its own put in for !!0) *)
let rec subst (cargs : S.t list) (margs : S.t list) (t : S.t) : S.t =
  let sub = subst cargs margs in
  match t with
  | S.Var n when n < List.length cargs -> List.nth cargs n
  | S.MVar n when n < List.length margs -> List.nth margs n
  | S.ByRef e -> S.ByRef (sub e) | S.Ptr e -> S.Ptr (sub e)
  | S.SzArray e -> S.SzArray (sub e) | S.Array (e, r) -> S.Array (sub e, r)
  | S.GenericInst (g, l) -> S.GenericInst (g, List.map sub l)
  | t -> t

let rec call_sig (img : Image.t) (tok : int) : S.meth * S.t option =
  (* (the signature, and the class it is on when known) *)
  let row = M.token_row tok in
  match M.token_table tok with
  | t when t = M.t_method_def -> (S.method_ (Image.blob img (Image.get img t row "Signature")), None)
  | t when t = M.t_member_ref ->
      let m = S.method_ (Image.blob img (Image.get img t row "Signature")) in
      let pt, pr = Image.decode M.member_ref_parent (Image.get img t row "Class") in
      let owner = if pt < 0 then None else Some (token_sig img (M.token pt pr)) in
      let cargs = match owner with Some (S.GenericInst (_, l)) -> l | _ -> [] in
      ({ m with ret = subst cargs [] m.ret; params = List.map (subst cargs []) m.params }, owner)
  | t when t = M.t_method_spec ->
      let mt, mr = Image.decode M.method_def_or_ref (Image.get img t row "Method") in
      let m, owner = call_sig img (M.token mt mr) in
      let margs = S.method_spec (Image.blob img (Image.get img t row "Instantiation")) in
      ({ m with ret = subst [] margs m.ret; params = List.map (subst [] margs) m.params }, owner)
  | _ -> bad (Printf.sprintf "a call to a token 0x%08x" tok)

let field_sig (img : Image.t) (tok : int) : S.t =
  let row = M.token_row tok in
  match M.token_table tok with
  | t when t = M.t_field -> S.field (Image.blob img (Image.get img t row "Signature"))
  | t when t = M.t_member_ref ->
      let f = S.field (Image.blob img (Image.get img t row "Signature")) in
      let pt, pr = Image.decode M.member_ref_parent (Image.get img t row "Class") in
      (match token_sig img (M.token pt pr) with S.GenericInst (_, l) -> subst l [] f | _ -> f)
  | _ -> bad "a field's token"

(* ------------------------------------------------------------------ *)
(* Compatibility, merging *)
(* ------------------------------------------------------------------ *)

(* can a stack's value of type [v] go where [want] is declared? *)
let fits (v : vt) (want : vt) : bool =
  match v, want with
  | (Int32 | Native), (Int32 | Native) -> true
  | Int64, Int64 | Float, Float -> true
  | Obj _, Obj _ -> true
  | Ptr _, (Ptr _ | Native) -> true
  (* (an unmanaged pointer, C#'s unsafe code, where a managed one is
   * asked: correct, not verifiable, and compiled the same) *)
  | Native, Ptr _ -> true
  | Value _, Value _ -> true
  | Gen _, _ | _, Gen _ -> true
  | _ -> false

let expect (what : string) (v : vt) (want : vt) : unit =
  if not (fits v want) then bad (Printf.sprintf "%s: %s where %s is expected" what (kind v) (kind want))

let merge (a : vt) (b : vt) : vt =
  match a, b with
  | Obj None, Obj _ -> b
  | Obj _, Obj _ -> a
  | (Int32 | Native), (Int32 | Native) when a <> b -> Native
  | _ when fits a b -> a
  | _ -> bad (Printf.sprintf "the stack differs where two paths join: %s and %s" (kind a) (kind b))

(* ------------------------------------------------------------------ *)
(* A method *)
(* ------------------------------------------------------------------ *)

type result = {
  stacks : vt list option array;     (* before each instruction, the top first; None: not reached *)
  instrs : Il.instr array;
}

let number (what : string) (v : vt) : unit =
  match v with
  | Int32 | Int64 | Native | Float -> ()
  | _ -> bad (Printf.sprintf "%s of %s" what (kind v))

(* Partition III, table 2 (binary numeric operations) and 5 (integer) *)
let binop (op : Il.binop) (a : vt) (b : vt) : vt =
  let name = match op with
    | Il.Add | Il.Add_ovf | Il.Add_ovf_un -> "add" | Il.Sub | Il.Sub_ovf | Il.Sub_ovf_un -> "sub"
    | Il.Mul | Il.Mul_ovf | Il.Mul_ovf_un -> "mul" | Il.Div | Il.Div_un -> "div"
    | Il.Rem | Il.Rem_un -> "rem" | Il.And -> "and" | Il.Or -> "or" | Il.Xor -> "xor"
    | Il.Shl -> "shl" | Il.Shr -> "shr" | Il.Shr_un -> "shr.un" in
  let fail () = bad (Printf.sprintf "%s of %s and %s" name (kind a) (kind b)) in
  match op with
  | Il.Shl | Il.Shr | Il.Shr_un ->
      (match a, b with
       | (Int32 | Int64 | Native), (Int32 | Native) -> a
       | _ -> fail ())
  | _ ->
      let integer = match op with
        | Il.And | Il.Or | Il.Xor | Il.Div_un | Il.Rem_un | Il.Add_ovf | Il.Add_ovf_un
        | Il.Sub_ovf | Il.Sub_ovf_un | Il.Mul_ovf | Il.Mul_ovf_un -> true
        | _ -> false in
      match a, b with
      | Int32, Int32 -> Int32
      | Int64, Int64 -> Int64
      | (Int32 | Native), (Int32 | Native) -> Native
      | Float, Float when not integer -> Float
      | Ptr _, (Int32 | Native) when op = Il.Add || op = Il.Sub -> a
      | (Int32 | Native), Ptr _ when op = Il.Add -> b
      | Ptr _, Ptr _ when op = Il.Sub -> Native
      | _ -> fail ()

let comparable (what : string) (a : vt) (b : vt) : unit =
  match a, b with
  | (Int32 | Native), (Int32 | Native) | Int64, Int64 | Float, Float -> ()
  | (Obj _ | Gen _), (Obj _ | Gen _) -> ()
  | Ptr _, Ptr _ -> ()
  | _ -> bad (Printf.sprintf "%s of %s and %s" what (kind a) (kind b))

let kind_vt (k : Il.kind) : vt =
  match k with
  | Il.K_i1 | Il.K_u1 | Il.K_i2 | Il.K_u2 | Il.K_i4 | Il.K_u4 -> Int32
  | Il.K_i8 | Il.K_u8 -> Int64
  | Il.K_i | Il.K_u -> Native
  | Il.K_r4 | Il.K_r8 -> Float
  | Il.K_ref -> Obj (Some S.Object)

let method_ (img : Image.t) (row : int) : result =
  let t = M.t_method_def in
  let rva = Image.get img t row "RVA" in
  if rva = 0 then bad "no body";
  let body = Image.body img rva in
  let instrs = Il.decode body.code in
  let n = Array.length instrs in
  let sg = S.method_ (Image.blob img (Image.get img t row "Signature")) in
  (* the owner: its `this` a reference, or a pointer for a struct's *)
  let owner =
    let rec find r = if r > img.rows.(M.t_type_def) then 1
      else let f, l = Image.range img M.t_type_def r "MethodList" t in
        if row >= f && row <= l then r else find (r + 1) in
    find 1 in
  let this_vt = match token_sig img (M.token M.t_type_def owner) with
    | S.ValueType _ as s -> Ptr s
    | s -> Obj (Some s) in
  let vt_of s = match of_sig img s with Some v -> v | None -> bad "a value of type void" in
  let args = Array.of_list ((if sg.has_this then [ this_vt ] else []) @ List.map vt_of sg.params) in
  let arg_sigs = Array.of_list ((if sg.has_this then [ S.Object ] else []) @ sg.params) in
  let locals =
    if body.locals_token = 0 then [||]
    else Array.of_list (S.locals (Image.blob img (Image.get img M.t_stand_alone_sig (M.token_row body.locals_token) "Signature"))) in
  let local_vt i = if i >= Array.length locals then bad (Printf.sprintf "no local %d" i) else vt_of locals.(i) in
  let ret = of_sig img sg.ret in
  let stacks = Array.make (n + 1) None in
  let work = ref [] in
  let flow (i : int) (s : vt list) =
    if i >= n then bad "the code falls off the method's end";
    match stacks.(i) with
    | None -> stacks.(i) <- Some s; work := i :: !work
    | Some old ->
        if List.length old <> List.length s then
          bad (Printf.sprintf "the stack is %d deep at IL_%04x by one path, %d by another"
                 (List.length old) instrs.(i).at (List.length s));
        let m = List.map2 merge old s in
        if m <> old then (stacks.(i) <- Some m; work := i :: !work) in
  flow 0 [];
  List.iter (fun (c : Image.clause) ->
      let i = Il.index instrs c.handler_start in
      (match c.kind with
       | 0 -> flow i [ Obj (Some (token_sig img c.class_token)) ]
       | 1 -> flow i [ Obj (Some S.Object) ]; flow (Il.index instrs c.class_token) [ Obj (Some S.Object) ]
       | _ -> flow i [])) body.clauses;
  let current = ref 0 in
  (try
     while !work <> [] do
       let i = List.hd !work in
       work := List.tl !work;
       current := i;
       let s = match stacks.(i) with Some s -> s | None -> [] in
       let ins = instrs.(i) in
       let st = ref s in
       let pop what = match !st with
         | v :: rest -> st := rest; v
         | [] -> bad (what ^ ": the stack is empty") in
       let push v = st := v :: !st in
       let next () = flow (i + 1) !st in
       let jump t = flow t !st in
       let call_args (m : S.meth) (what : string) =
         List.iter (fun p -> expect what (pop what) (vt_of p)) (List.rev m.params) in
       (match ins.op with
        | Il.Nop | Il.Break | Il.Prefix _ | Il.Constrained _ -> next ()
        | Il.Ldarg a -> if a >= Array.length args then bad "no such argument"; push args.(a); next ()
        | Il.Ldarga a -> if a >= Array.length args then bad "no such argument"; push (Ptr arg_sigs.(a)); next ()
        | Il.Starg a -> expect "starg" (pop "starg") args.(a); next ()
        | Il.Ldloc l -> push (local_vt l); next ()
        | Il.Ldloca l -> ignore (local_vt l); push (Ptr locals.(l)); next ()
        | Il.Stloc l -> expect "stloc" (pop "stloc") (local_vt l); next ()
        | Il.Ldnull -> push (Obj None); next ()
        | Il.Ldc_i4 _ -> push Int32; next ()
        | Il.Ldc_i8 _ -> push Int64; next ()
        | Il.Ldc_r _ -> push Float; next ()
        | Il.Ldstr _ -> push (Obj (Some S.String)); next ()
        | Il.Dup -> let v = pop "dup" in push v; push v; next ()
        | Il.Pop -> ignore (pop "pop"); next ()
        | Il.Call tok | Il.Callvirt tok ->
            let m, _ = call_sig img tok in
            call_args m "an argument";
            if m.has_this then begin
              let this = pop "this" in
              (match this with
               | Int32 | Int64 | Float -> bad (Printf.sprintf "a call's this: %s" (kind this))
               | _ -> ())
            end;
            (match of_sig img m.ret with Some v -> push v | None -> ());
            next ()
        | Il.Newobj tok ->
            let m, owner = call_sig img tok in
            call_args m "a constructor's argument";
            let cls = match owner with
              | Some o -> o
              | None ->
                  (* (a MethodDef: its TypeDef) *)
                  let r = M.token_row tok in
                  let rec find c = if c > img.rows.(M.t_type_def) then 1
                    else let f, l = Image.range img M.t_type_def c "MethodList" M.t_method_def in
                      if r >= f && r <= l then c else find (c + 1) in
                  token_sig img (M.token M.t_type_def (find 1)) in
            push (match vt_of cls with Value _ as v -> v | Int32 | Int64 | Native | Float as v -> v | _ -> Obj (Some cls));
            next ()
        | Il.Calli tok ->
            let m = S.method_ (Image.blob img (Image.get img M.t_stand_alone_sig (M.token_row tok) "Signature")) in
            expect "calli's function" (pop "calli") Native;
            call_args m "an argument";
            if m.has_this then ignore (pop "this");
            (match of_sig img m.ret with Some v -> push v | None -> ());
            next ()
        | Il.Ret ->
            (match ret with Some r -> expect "ret" (pop "ret") r | None -> ());
            if !st <> [] then bad (Printf.sprintf "ret with the stack %d deep, not empty" (List.length !st))
        | Il.Br t -> jump t
        | Il.Brfalse t | Il.Brtrue t ->
            (match pop "a branch's condition" with
             | Float | Value _ as v -> bad ("a branch on " ^ kind v)
             | _ -> ());
            jump t; next ()
        | Il.Bcmp (_, _, t) ->
            let b = pop "a comparison" in
            let a = pop "a comparison" in
            comparable "a branch's comparison" a b;
            jump t; next ()
        | Il.Switch ts ->
            expect "switch" (pop "switch") Int32;
            Array.iter jump ts; next ()
        | Il.Ldind k -> expect "ldind" (pop "ldind") (Ptr S.Object); push (kind_vt k); next ()
        | Il.Stind _ -> ignore (pop "stind"); expect "stind" (pop "stind") (Ptr S.Object); next ()
        | Il.Binop o -> let b = pop "an operand" in let a = pop "an operand" in push (binop o a b); next ()
        | Il.Neg -> let v = pop "neg" in number "neg" v; push v; next ()
        | Il.Not ->
            let v = pop "not" in
            (match v with Int32 | Int64 | Native -> push v | _ -> bad ("not of " ^ kind v));
            next ()
        | Il.Conv (k, _, _) ->
            let v = pop "conv" in
            (match v, k with
             | (Int32 | Int64 | Native | Float), _ -> ()
             | (Ptr _ | Obj _), (Il.K_i | Il.K_u | Il.K_i8 | Il.K_u8) -> ()
             | _ -> bad ("conv of " ^ kind v));
            push (kind_vt k); next ()
        | Il.Conv_r_un -> number "conv.r.un" (pop "conv.r.un"); push Float; next ()
        | Il.Ceq | Il.Cgt _ | Il.Clt _ ->
            let b = pop "a comparison" in
            let a = pop "a comparison" in
            comparable "a comparison" a b; push Int32; next ()
        | Il.Ldobj tok -> ignore (pop "ldobj"); push (token_vt img tok); next ()
        | Il.Stobj _ -> ignore (pop "stobj"); expect "stobj" (pop "stobj") (Ptr S.Object); next ()
        | Il.Cpobj _ -> ignore (pop "cpobj"); ignore (pop "cpobj"); next ()
        | Il.Ldfld tok | Il.Ldflda tok ->
            let o = pop "ldfld" in
            (match o with Int32 | Int64 | Float -> bad ("a field of " ^ kind o) | _ -> ());
            let f = field_sig img tok in
            push (match ins.op with Il.Ldflda _ -> Ptr f | _ -> vt_of f); next ()
        | Il.Stfld tok ->
            let v = pop "stfld" in
            expect "stfld" v (vt_of (field_sig img tok));
            let o = pop "stfld" in
            (match o with Int32 | Int64 | Float -> bad ("a field of " ^ kind o) | _ -> ());
            next ()
        | Il.Ldsfld tok -> push (vt_of (field_sig img tok)); next ()
        | Il.Ldsflda tok -> push (Ptr (field_sig img tok)); next ()
        | Il.Stsfld tok -> expect "stsfld" (pop "stsfld") (vt_of (field_sig img tok)); next ()
        | Il.Newarr tok ->
            expect "newarr's length" (pop "newarr") Int32;
            push (Obj (Some (S.SzArray (token_sig img tok)))); next ()
        | Il.Ldlen -> expect "ldlen" (pop "ldlen") (Obj None); push Native; next ()
        | Il.Ldelema tok ->
            expect "an index" (pop "ldelema") Int32; expect "an array" (pop "ldelema") (Obj None);
            push (Ptr (token_sig img tok)); next ()
        | Il.Ldelem k ->
            expect "an index" (pop "ldelem") Int32; expect "an array" (pop "ldelem") (Obj None);
            push (kind_vt k); next ()
        | Il.Ldelem_any tok ->
            expect "an index" (pop "ldelem") Int32; expect "an array" (pop "ldelem") (Obj None);
            push (token_vt img tok); next ()
        | Il.Stelem k ->
            expect "stelem" (pop "stelem") (kind_vt k);
            expect "an index" (pop "stelem") Int32; expect "an array" (pop "stelem") (Obj None); next ()
        | Il.Stelem_any tok ->
            expect "stelem" (pop "stelem") (token_vt img tok);
            expect "an index" (pop "stelem") Int32; expect "an array" (pop "stelem") (Obj None); next ()
        | Il.Box tok -> ignore (pop "box"); push (Obj (Some (token_sig img tok))); next ()
        | Il.Unbox tok -> expect "unbox" (pop "unbox") (Obj None); push (Ptr (token_sig img tok)); next ()
        | Il.Unbox_any tok -> ignore (pop "unbox.any"); push (token_vt img tok); next ()
        | Il.Castclass tok | Il.Isinst tok ->
            let v = pop "a cast" in
            (match v with Obj _ | Gen _ -> () | _ -> bad ("a cast of " ^ kind v));
            push (Obj (Some (token_sig img tok))); next ()
        | Il.Throw -> expect "throw" (pop "throw") (Obj None)
        | Il.Rethrow -> ()
        | Il.Leave t -> st := []; jump t
        | Il.Endfinally -> ()
        | Il.Endfilter -> expect "endfilter" (pop "endfilter") Int32
        | Il.Ldtoken tok ->
            push (Value (if M.token_table tok = M.t_field then S.I else S.ValueType tok)); next ()
        | Il.Ldftn _ -> push Native; next ()
        | Il.Ldvirtftn _ -> expect "ldvirtftn" (pop "ldvirtftn") (Obj None); push Native; next ()
        | Il.Initobj _ -> expect "initobj" (pop "initobj") (Ptr S.Object); next ()
        | Il.Sizeof _ -> push Int32; next ()
        | Il.Localloc -> expect "localloc" (pop "localloc") Native; push Native; next ()
        | Il.Cpblk | Il.Initblk -> ignore (pop "blk"); ignore (pop "blk"); ignore (pop "blk"); next ()
        | Il.Ckfinite -> expect "ckfinite" (pop "ckfinite") Float; push Float; next ()
        | Il.Jmp _ | Il.Arglist | Il.Mkrefany _ | Il.Refanyval _ | Il.Refanytype ->
            bad (ins.name ^ ": not verified by mini-dotnet"));
       if List.length !st > body.max_stack + 0 && body.max_stack >= 0 then
         (match ins.op with
          | Il.Ret | Il.Throw | Il.Rethrow | Il.Endfinally | Il.Endfilter | Il.Leave _ | Il.Br _ -> ()
          | _ -> if List.length !st > body.max_stack then
                bad (Printf.sprintf "the stack %d deep, past its .maxstack %d" (List.length !st) body.max_stack))
     done
   with Bad msg ->
     let at = if !current < n then instrs.(!current).at else 0 in
     bad (Printf.sprintf "IL_%04x: %s" at msg));
  { stacks; instrs }

let assembly (img : Image.t) : int * (int * string) list =
  let ok = ref 0 and errors = ref [] in
  for row = 1 to img.rows.(M.t_method_def) do
    if Image.get img M.t_method_def row "RVA" <> 0 then
      match method_ img row with
      | _ -> incr ok
      | exception Bad msg -> errors := (row, msg) :: !errors
      | exception (Il.Bad_il msg | Image.Bad_image msg) -> errors := (row, msg) :: !errors
      | exception e -> errors := (row, "not read: " ^ Printexc.to_string e) :: !errors
  done;
  (!ok, List.rev !errors)
