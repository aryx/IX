(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Types.mli *)

open Value
module M = Metadata
module S = Signature

exception Load_error of string

let error (s : string) = raise (Load_error s)

type ctx = { im : image; targs : typ array; margs : typ array }

(* the assemblies, in the order they were loaded *)
let images : image list ref = ref []

(* every class made, by its name with its arguments *)
let classes : (string, cls) Hashtbl.t = Hashtbl.create 64

(* an assembly's tables turned around: a TypeDef by its full name, the
 * owner of a method's and a field's row, the generic parameters of a
 * TypeDef *)
type extra = {
  by_name : (string, int) Hashtbl.t;
  method_owner : int array;
  field_owner : int array;
  generics : int array;
}
let extras : (string, extra) Hashtbl.t = Hashtbl.create 4
let extra (im : image) : extra = Hashtbl.find extras im.aname

(* ------------------------------------------------------------------ *)
(* Names *)
(* ------------------------------------------------------------------ *)

let dotted (ns : string) (n : string) : string = if ns = "" then n else ns ^ "." ^ n

let enclosing (img : Image.t) (row : int) : int =
  let t = img.tables.(M.t_nested_class) in
  let rec go i =
    if i >= Array.length t then 0 else if t.(i).(0) = row then t.(i).(1) else go (i + 1) in
  go 1

let rec def_name (img : Image.t) (row : int) : string =
  let t = M.t_type_def in
  let n = dotted (Image.string img (Image.get img t row "TypeNamespace"))
            (Image.string img (Image.get img t row "TypeName")) in
  match enclosing img row with
  | 0 -> n
  | outer -> def_name img outer ^ "+" ^ n

let rec ref_name (img : Image.t) (row : int) : string =
  let t = M.t_type_ref in
  let n = dotted (Image.string img (Image.get img t row "TypeNamespace"))
            (Image.string img (Image.get img t row "TypeName")) in
  let st, sr = Image.decode M.resolution_scope (Image.get img t row "ResolutionScope") in
  if st = M.t_type_ref then ref_name img sr ^ "+" ^ n else n

(* a class's name instantiated: Stack`1[System.Int32], as ToString *)
let inst_name (base : string) (args : typ array) : string =
  if args = [||] then base
  else base ^ "[" ^ String.concat "," (Array.to_list (Array.map typ_key args)) ^ "]"

let short_of (base : string) : string =
  let cut c s = match String.rindex_opt s c with
    | Some i -> String.sub s (i + 1) (String.length s - i - 1) | None -> s in
  cut '+' (cut '.' base)

(* a signature as a key, its classes by their names: the same whether
 * written in this assembly (a TypeDef) or another (a TypeRef), so a
 * MemberRef finds its method *)
let rec sig_key (img : Image.t) (t : S.t) : string =
  let tok_name tok =
    let row = M.token_row tok in
    match M.token_table tok with
    | x when x = M.t_type_def -> def_name img row
    | x when x = M.t_type_ref -> ref_name img row
    | _ -> sig_key img (S.type_spec (Image.blob img (Image.get img M.t_type_spec row "Signature"))) in
  match t with
  | S.Void -> "System.Void" | S.Bool -> "System.Boolean" | S.Char -> "System.Char"
  | S.I1 -> "System.SByte" | S.U1 -> "System.Byte" | S.I2 -> "System.Int16"
  | S.U2 -> "System.UInt16" | S.I4 -> "System.Int32" | S.U4 -> "System.UInt32"
  | S.I8 -> "System.Int64" | S.U8 -> "System.UInt64" | S.R4 -> "System.Single"
  | S.R8 -> "System.Double" | S.I -> "System.IntPtr" | S.U -> "System.UIntPtr"
  | S.String -> "System.String" | S.Object -> "System.Object"
  | S.TypedRef -> "System.TypedReference"
  | S.Class tok | S.ValueType tok -> tok_name tok
  | S.Var n -> "!" ^ string_of_int n
  | S.MVar n -> "!!" ^ string_of_int n
  | S.Ptr t -> sig_key img t ^ "*"
  | S.ByRef t -> sig_key img t ^ "&"
  | S.SzArray t -> sig_key img t ^ "[]"
  | S.Array (t, r) -> sig_key img t ^ "[" ^ String.make (r - 1) ',' ^ "]"
  | S.GenericInst (g, args) ->
      sig_key img g ^ "<" ^ String.concat "," (List.map (sig_key img) args) ^ ">"
  | S.FnPtr _ -> "System.IntPtr"

let meth_sig_key (img : Image.t) (name : string) (m : S.meth) : string =
  name ^ "(" ^ String.concat "," (List.map (sig_key img) m.params) ^ ")" ^ sig_key img m.ret

(* ------------------------------------------------------------------ *)
(* Types and classes *)
(* ------------------------------------------------------------------ *)

let primitives = [
  "System.Boolean", T_bool; "System.Char", T_char; "System.SByte", T_i1;
  "System.Byte", T_u1; "System.Int16", T_i2; "System.UInt16", T_u2;
  "System.Int32", T_i4; "System.UInt32", T_u4; "System.Int64", T_i8;
  "System.UInt64", T_u8; "System.Single", T_r4; "System.Double", T_r8;
  "System.IntPtr", T_i; "System.UIntPtr", T_u; "System.Void", T_void;
]

let typ_of_cls (c : cls) : typ =
  match List.assoc_opt c.name primitives with
  | Some t -> t
  | None ->
      match c.kind with
      | Enum -> (match List.find_opt (fun (f : field) -> not f.fstatic) c.fields with
          | Some f -> f.ftype | None -> T_i4)
      | Struct -> T_value c
      | Class | Interface | Delegate -> T_class c

let is_value_type (t : typ) : bool =
  match t with
  | T_class _ | T_array _ | T_byref _ | T_ptr _ | T_void | T_var _ | T_mvar _ -> false
  | _ -> true

(* a new class, before its parent, fields and methods are known: in the
 * table first, so a field of its own type finds it *)
let new_cls (name : string) (short : string) (kind : kind) (args : typ array) (origin : origin) : cls =
  let c = { name; short; kind; args; parent = None; interfaces = []; fields = [];
            methods = []; vtable = [||]; nbytes = 0; nrefs = 0; statics = None;
            init = Not_run; element = None; imap = Hashtbl.create 4; origin } in
  Hashtbl.replace classes name c;
  c

(* the fields laid out, the instance ones after the parent's, the
 * static ones in a store of their own *)
let layout (c : cls) : unit =
  let b, r = match c.parent with Some p -> (p.nbytes, p.nrefs) | None -> (0, 0) in
  let b = ref b and r = ref r and sb = ref 0 and sr = ref 0 in
  List.iter (fun (f : field) ->
      let fb, fr = match f.ftype with
        | T_value v -> (v.nbytes, v.nrefs)
        | t when is_ref t -> (0, 1)
        | t -> (scalar_size t, 0) in
      let bytes, refs = if f.fstatic then (sb, sr) else (b, r) in
      f.off <- !bytes; f.roff <- !refs;
      bytes := !bytes + fb; refs := !refs + fr) c.fields;
  c.nbytes <- !b; c.nrefs <- !r;
  if !sb > 0 || !sr > 0 then
    c.statics <- Some { cls = c; s = Bytes.make !sb '\000'; r = Array.make !sr Null; len = 0; native = No_native }

(* a method's key as overrides compare it: its types instantiated *)
let ikey (m : meth) : string = meth_key m.mname m.params m.ret

(* the virtual methods' slots: the parent's table, a method overriding
 * one in its slot, a new one at the end *)
let vtable (c : cls) : unit =
  let vt = ref (match c.parent with Some p -> Array.to_list p.vtable | None -> []) in
  List.iter (fun (m : meth) ->
      if m.virt && c.kind <> Interface then begin
        let rec find i l = match l with
          | [] -> -1
          | (x : meth) :: rest -> if x.mname = m.mname && ikey x = ikey m then i else find (i + 1) rest in
        match if m.newslot then -1 else find 0 !vt with
        | -1 -> m.slot <- List.length !vt; vt := !vt @ [m]
        | i -> m.slot <- i; vt := List.mapi (fun j x -> if j = i then m else x) !vt
      end) c.methods;
  c.vtable <- Array.of_list !vt

let array_classes : (string, cls) Hashtbl.t = Hashtbl.create 16

(* a generic method's instantiations, each once: its IL decoded once,
 * its tokens' cache kept *)
let instances : (string, meth) Hashtbl.t = Hashtbl.create 16

(* the library's classes, made from their description *)
let rec class_of_spec (sp : Library.spec) (args : typ array) : cls =
  let name = inst_name sp.sname args in
  match Hashtbl.find_opt classes name with
  | Some c -> c
  | None ->
      let c = new_cls name (short_of sp.sname) sp.skind args Builtin in
      if sp.sparent <> "" then c.parent <- Some (find_class sp.sparent [||]);
      c.interfaces <- List.map (fun i -> class_of_typ (parse args [||] i)) sp.sinterfaces;
      c.fields <- List.map (fun (n, t) ->
          { fname = n; fcls = c; ftype = parse args [||] t; fstatic = false; off = 0; roff = 0 })
          sp.sfields;
      layout c;
      c.methods <- List.map (fun (sm : Library.smeth) ->
          { mname = sm.mn; mcls = c; static = sm.mstatic; virt = sm.mvirt;
            abstract = (sm.impl = Library.Abstract); newslot = false;
            params = List.map (parse args [||]) sm.mparams; ret = parse args [||] sm.mret;
            generic = sm.mgeneric; margs = [||];
            key = sm.mn ^ "(" ^ String.concat "," sm.mparams ^ ")" ^ sm.mret;
            slot = -1;
            body = (match sm.impl with
                | Library.Impl f -> Native f
                | Library.By_runtime -> Runtime
                | Library.Abstract -> No_body);
            def = None; cache = Hashtbl.create 1 })
          sp.smethods;
      vtable c;
      c

(* a type's key, as the library writes them, read: "System.Int32",
 * "!0", "!!0[]", "System.Collections.Generic.List`1+Enumerator<!0>" *)
and parse (targs : typ array) (margs : typ array) (s : string) : typ =
  let n = String.length s in
  let pos = ref 0 in
  let rec typ () : typ =
    let base =
      if !pos < n && s.[!pos] = '!' then begin
        let mvar = !pos + 1 < n && s.[!pos + 1] = '!' in
        pos := !pos + (if mvar then 2 else 1);
        let start = !pos in
        while !pos < n && s.[!pos] >= '0' && s.[!pos] <= '9' do incr pos done;
        let k = int_of_string (String.sub s start (!pos - start)) in
        if mvar then (if k < Array.length margs then margs.(k) else T_mvar k)
        else (if k < Array.length targs then targs.(k) else T_var k)
      end else begin
        let start = !pos in
        while !pos < n && not (List.mem s.[!pos] ['<'; '>'; ','; '['; '&'; '*']) do incr pos done;
        let name = String.sub s start (!pos - start) in
        let args =
          if !pos < n && s.[!pos] = '<' then begin
            incr pos;
            let rec go acc =
              let t = typ () in
              if s.[!pos] = ',' then (incr pos; go (t :: acc))
              else (incr pos; List.rev (t :: acc)) in
            Array.of_list (go [])
          end else [||] in
        match List.assoc_opt name primitives with
        | Some t -> t
        | None -> typ_of_cls (find_class name args)
      end in
    suffix base
  and suffix t =
    if !pos + 1 < n && s.[!pos] = '[' && s.[!pos + 1] = ']' then (pos := !pos + 2; suffix (T_array t))
    else if !pos < n && s.[!pos] = '&' then (incr pos; suffix (T_byref t))
    else if !pos < n && s.[!pos] = '*' then (incr pos; suffix (T_ptr t))
    else t in
  typ ()

and find_class (name : string) (args : typ array) : cls =
  match Hashtbl.find_opt classes (inst_name name args) with
  | Some c -> c
  | None ->
      match Hashtbl.find_opt Library.specs name with
      | Some sp -> class_of_spec sp args
      | None ->
          let rec go l = match l with
            | [] -> error ("no class " ^ name ^ " (mini-dotnet's library has not got it)")
            | im :: rest ->
                match Hashtbl.find_opt (extra im).by_name name with
                | Some row -> class_of_def im row args
                | None -> go rest in
          go !images

and class_of_typ (t : typ) : cls =
  match t with
  | T_class c | T_value c -> c
  | T_array e -> array_class e
  | T_byref _ | T_ptr _ -> find_class "System.IntPtr" [||]
  | T_var _ | T_mvar _ -> find_class "System.Object" [||]
  | t -> find_class (typ_key t) [||]

and array_class (e : typ) : cls =
  let name = typ_key e ^ "[]" in
  match Hashtbl.find_opt array_classes name with
  | Some c -> c
  | None ->
      let c = new_cls name (short_of (typ_key e) ^ "[]") Class [||] Builtin in
      Hashtbl.replace array_classes name c;
      c.parent <- Some (find_class "System.Array" [||]);
      c.element <- Some e;
      c.vtable <- (match c.parent with Some p -> p.vtable | None -> [||]);
      c

(* an assembly's class *)
and class_of_def (im : image) (row : int) (args : typ array) : cls =
  let img = im.img in
  let base = def_name img row in
  let name = inst_name base args in
  match Hashtbl.find_opt classes name with
  | Some c -> c
  | None ->
      Logs.debug (fun m -> m "class %s loaded" name);
      let t = M.t_type_def in
      let flags = Image.get img t row "Flags" in
      let et, er = Image.decode M.type_def_or_ref (Image.get img t row "Extends") in
      let parent_name =
        if et < 0 then ""
        else if et = M.t_type_def then def_name img er
        else if et = M.t_type_ref then ref_name img er
        else match S.type_spec (Image.blob img (Image.get img M.t_type_spec er "Signature")) with
          | S.GenericInst ((S.Class tok | S.ValueType tok), _) ->
              (match M.token_table tok with
               | x when x = M.t_type_def -> def_name img (M.token_row tok)
               | _ -> ref_name img (M.token_row tok))
          | _ -> "" in
      let kind =
        if flags land 0x20 <> 0 then Interface
        else match parent_name with
          | "System.ValueType" when base <> "System.Enum" -> Struct
          | "System.Enum" -> Enum
          | "System.MulticastDelegate" -> Delegate
          | _ -> Class in
      let c = new_cls name (short_of base) kind args (From (im, row)) in
      let ctx = { im; targs = args; margs = [||] } in
      if et >= 0 then c.parent <- Some (class_of_typ (typ_of_token ctx (M.token et er)));
      for i = 1 to img.rows.(M.t_interface_impl) do
        if Image.get img M.t_interface_impl i "Class" = row then
          let it, ir = Image.decode M.type_def_or_ref (Image.get img M.t_interface_impl i "Interface") in
          c.interfaces <- c.interfaces @ [class_of_typ (typ_of_token ctx (M.token it ir))]
      done;
      let ff, fl = Image.range img t row "FieldList" M.t_field in
      for f = ff to fl do
        let fflags = Image.get img M.t_field f "Flags" in
        (* (a literal, const, has no room: its uses are the constant) *)
        if fflags land 0x40 = 0 then
          c.fields <- c.fields @ [
            { fname = Image.string img (Image.get img M.t_field f "Name"); fcls = c;
              ftype = sig_typ ctx (S.field (Image.blob img (Image.get img M.t_field f "Signature")));
              fstatic = fflags land 0x10 <> 0; off = 0; roff = 0 } ]
      done;
      layout c;
      let mf, ml = Image.range img t row "MethodList" M.t_method_def in
      for m = mf to ml do c.methods <- c.methods @ [method_of_def im m c [||]] done;
      vtable c;
      (* explicit implementations: MethodImpl's rows *)
      for i = 1 to img.rows.(M.t_method_impl) do
        if Image.get img M.t_method_impl i "Class" = row then begin
          let bt, br = Image.decode M.method_def_or_ref (Image.get img M.t_method_impl i "MethodBody") in
          let dt, dr = Image.decode M.method_def_or_ref (Image.get img M.t_method_impl i "MethodDeclaration") in
          let body = meth_of_token ctx (M.token bt br) in
          let decl = meth_of_token ctx (M.token dt dr) in
          if decl.mcls.kind = Interface then Hashtbl.replace c.imap (decl.mcls.name ^ "::" ^ ikey decl) body
          else if decl.slot >= 0 then (body.slot <- decl.slot; c.vtable.(decl.slot) <- body)
        end
      done;
      c

and method_of_def (im : image) (row : int) (c : cls) (margs : typ array) : meth =
  let img = im.img in
  let t = M.t_method_def in
  let flags = Image.get img t row "Flags" in
  let name = Image.string img (Image.get img t row "Name") in
  let sg = S.method_ (Image.blob img (Image.get img t row "Signature")) in
  let ctx = { im; targs = c.args; margs } in
  let rva = Image.get img t row "RVA" in
  { mname = name; mcls = c; static = flags land 0x10 <> 0; virt = flags land 0x40 <> 0;
    abstract = flags land 0x400 <> 0; newslot = flags land 0x100 <> 0;
    params = List.map (sig_typ ctx) sg.params; ret = sig_typ ctx sg.ret;
    generic = sg.generic; margs; key = meth_sig_key img name sg; slot = -1;
    body = (if rva <> 0 then Il_body rva
            else if c.kind = Delegate || Image.get img t row "ImplFlags" land 3 = 3 then Runtime
            else No_body);
    def = Some (im, row); cache = Hashtbl.create 8 }

and sig_typ (ctx : ctx) (t : S.t) : typ =
  match t with
  | S.Void -> T_void | S.Bool -> T_bool | S.Char -> T_char
  | S.I1 -> T_i1 | S.U1 -> T_u1 | S.I2 -> T_i2 | S.U2 -> T_u2
  | S.I4 -> T_i4 | S.U4 -> T_u4 | S.I8 -> T_i8 | S.U8 -> T_u8
  | S.R4 -> T_r4 | S.R8 -> T_r8 | S.I -> T_i | S.U -> T_u
  | S.String -> T_class (find_class "System.String" [||])
  | S.Object -> T_class (find_class "System.Object" [||])
  | S.TypedRef -> error "a typedref: not in mini-dotnet"
  | S.Class tok | S.ValueType tok -> typ_of_token ctx tok
  | S.Var n -> if n < Array.length ctx.targs then ctx.targs.(n) else T_var n
  | S.MVar n -> if n < Array.length ctx.margs then ctx.margs.(n) else T_mvar n
  | S.Ptr t -> T_ptr (sig_typ ctx t)
  | S.ByRef t -> T_byref (sig_typ ctx t)
  | S.SzArray t -> T_array (sig_typ ctx t)
  | S.Array _ -> error "an array of several dimensions: not in mini-dotnet"
  | S.GenericInst (g, args) ->
      let args = Array.of_list (List.map (sig_typ ctx) args) in
      let tok = match g with S.Class t | S.ValueType t -> t | _ -> error "a generic instance of what?" in
      let img = ctx.im.img in
      let row = M.token_row tok in
      if M.token_table tok = M.t_type_def then typ_of_cls (class_of_def ctx.im row args)
      else typ_of_cls (find_class (ref_name img row) args)
  | S.FnPtr _ -> T_i

and typ_of_token (ctx : ctx) (tok : int) : typ =
  let img = ctx.im.img in
  let row = M.token_row tok in
  match M.token_table tok with
  | x when x = M.t_type_def ->
      let n = (extra ctx.im).generics.(row) in
      (* (a generic class named bare, in its own code: its arguments
       * are the context's) *)
      typ_of_cls (class_of_def ctx.im row (if n > 0 then Array.sub ctx.targs 0 n else [||]))
  | x when x = M.t_type_ref ->
      let name = ref_name img row in
      (match List.assoc_opt name primitives with
       | Some t -> t
       | None -> typ_of_cls (find_class name [||]))
  | x when x = M.t_type_spec ->
      sig_typ ctx (S.type_spec (Image.blob img (Image.get img M.t_type_spec row "Signature")))
  | x -> error (Printf.sprintf "a type's token in %s" (M.name x))

and meth_of_token (ctx : ctx) (tok : int) : meth =
  let img = ctx.im.img in
  let row = M.token_row tok in
  match M.token_table tok with
  | x when x = M.t_method_def ->
      let owner = (extra ctx.im).method_owner.(row) in
      let n = (extra ctx.im).generics.(owner) in
      let c = class_of_def ctx.im owner (if n > 0 then Array.sub ctx.targs 0 n else [||]) in
      (match List.find_opt (fun (m : meth) -> m.def = Some (ctx.im, row)) c.methods with
       | Some m -> m
       | None -> error "a MethodDef in no class")
  | x when x = M.t_member_ref ->
      let pt, pr = Image.decode M.member_ref_parent (Image.get img x row "Class") in
      let c = class_of_typ (typ_of_token ctx (M.token pt pr)) in
      let name = Image.string img (Image.get img x row "Name") in
      let key = meth_sig_key img name (S.method_ (Image.blob img (Image.get img x row "Signature"))) in
      let rec find (c : cls) = match List.find_opt (fun (m : meth) -> m.key = key) c.methods with
        | Some m -> m
        | None -> match c.parent with
          | Some p -> find p
          | None -> error ("no method " ^ c.name ^ "::" ^ key) in
      find c
  | x when x = M.t_method_spec ->
      let mt, mr = Image.decode M.method_def_or_ref (Image.get img x row "Method") in
      let m = meth_of_token ctx (M.token mt mr) in
      let args = S.method_spec (Image.blob img (Image.get img x row "Instantiation")) in
      instantiate m (Array.of_list (List.map (sig_typ ctx) args))
  | x -> error (Printf.sprintf "a method's token in %s" (M.name x))

and instantiate (m : meth) (args : typ array) : meth =
  let k = m.mcls.name ^ "::" ^ m.key ^ "<" ^ String.concat "," (Array.to_list (Array.map typ_key args)) ^ ">" in
  match Hashtbl.find_opt instances k with
  | Some x -> x
  | None ->
      let x = instantiate_new m args in
      Hashtbl.replace instances k x;
      x

and instantiate_new (m : meth) (args : typ array) : meth =
  match m.def with
  | Some (im, row) -> method_of_def im row m.mcls args
  | None ->
      let rec subst t = match t with
        | T_mvar k when k < Array.length args -> args.(k)
        | T_array e -> T_array (subst e)
        | T_byref e -> T_byref (subst e)
        | t -> t in
      { m with margs = args; params = List.map subst m.params; ret = subst m.ret;
               cache = Hashtbl.create 1 }

let field_of_token (ctx : ctx) (tok : int) : field =
  let img = ctx.im.img in
  let row = M.token_row tok in
  let find (c : cls) (name : string) =
    let rec go (c : cls) = match List.find_opt (fun (f : field) -> f.fname = name) c.fields with
      | Some f -> f
      | None -> match c.parent with Some p -> go p | None -> error ("no field " ^ c.name ^ "::" ^ name) in
    go c in
  match M.token_table tok with
  | x when x = M.t_field ->
      let owner = (extra ctx.im).field_owner.(row) in
      let n = (extra ctx.im).generics.(owner) in
      let c = class_of_def ctx.im owner (if n > 0 then Array.sub ctx.targs 0 n else [||]) in
      find c (Image.string img (Image.get img x row "Name"))
  | x when x = M.t_member_ref ->
      let pt, pr = Image.decode M.member_ref_parent (Image.get img x row "Class") in
      let c = class_of_typ (typ_of_token ctx (M.token pt pr)) in
      find c (Image.string img (Image.get img x row "Name"))
  | x -> error (Printf.sprintf "a field's token in %s" (M.name x))

let meth_of_def (im : image) (row : int) : meth =
  meth_of_token { im; targs = [||]; margs = [||] } (M.token M.t_method_def row)

let virtual_target (c : cls) (m : meth) : meth =
  if m.mcls.kind = Interface then begin
    let k = m.mcls.name ^ "::" ^ ikey m in
    let rec explicit (c : cls) = match Hashtbl.find_opt c.imap k with
      | Some x -> Some x
      | None -> match c.parent with Some p -> explicit p | None -> None in
    match explicit c with
    | Some x -> x
    | None ->
        let key = ikey m in
        let found = ref None in
        Array.iter (fun (x : meth) -> if x.mname = m.mname && ikey x = key then found := Some x) c.vtable;
        (* (a struct's or a sealed class's method, not virtual) *)
        let rec own (c : cls) = match List.find_opt (fun (x : meth) -> x.mname = m.mname && ikey x = key && not x.static) c.methods with
          | Some x -> Some x | None -> (match c.parent with Some p -> own p | None -> None) in
        match (match !found with Some x -> Some x | None -> own c) with
        | Some x -> Hashtbl.replace c.imap k x; x
        | None -> error ("no implementation of " ^ m.mcls.name ^ "::" ^ m.mname ^ " in " ^ c.name)
  end
  else if m.slot >= 0 && m.slot < Array.length c.vtable then c.vtable.(m.slot)
  else m

let ctx_of (m : meth) : ctx =
  match m.def with
  | Some (im, _) -> { im; targs = m.mcls.args; margs = m.margs }
  | None -> error "a native method has no context"

let code (m : meth) : code =
  match m.body with
  | Decoded c -> c
  | Il_body rva ->
      let im = match m.def with Some (im, _) -> im | None -> error "IL without its assembly" in
      let body = Image.body im.img rva in
      let instrs = Il.decode body.code in
      let ctx = ctx_of m in
      let locals =
        if body.locals_token = 0 then [||]
        else
          let row = M.token_row body.locals_token in
          Array.of_list (List.map (sig_typ ctx)
                           (S.locals (Image.blob im.img (Image.get im.img M.t_stand_alone_sig row "Signature")))) in
      let clauses = Array.of_list (List.map (fun (cl : Image.clause) ->
          let ix = Il.index instrs in
          { ckind = cl.kind; tstart = ix cl.try_start; tend = ix cl.try_end;
            hstart = ix cl.handler_start; hend = ix cl.handler_end;
            catch = if cl.kind = 0 then Some (class_of_typ (typ_of_token ctx cl.class_token)) else None;
            filter = if cl.kind = 1 then ix cl.class_token else -1 })
          body.clauses) in
      let c = { instrs; clauses; locals; max_stack = body.max_stack } in
      m.body <- Decoded c;
      c
  | _ -> error (m.mcls.name ^ "::" ^ m.mname ^ " has no IL")

let load (img : Image.t) : image =
  let aname = if img.rows.(M.t_assembly) > 0
    then Image.string img (Image.get img M.t_assembly 1 "Name") else "module" in
  let im = { img; aname; types = Hashtbl.create 16; strings = Hashtbl.create 16 } in
  let ntypes = img.rows.(M.t_type_def) in
  let by_name = Hashtbl.create 16 in
  let method_owner = Array.make (img.rows.(M.t_method_def) + 1) 0 in
  let field_owner = Array.make (img.rows.(M.t_field) + 1) 0 in
  let generics = Array.make (ntypes + 1) 0 in
  for r = 1 to ntypes do
    Hashtbl.replace by_name (def_name img r) r;
    let mf, ml = Image.range img M.t_type_def r "MethodList" M.t_method_def in
    for m = mf to ml do method_owner.(m) <- r done;
    let ff, fl = Image.range img M.t_type_def r "FieldList" M.t_field in
    for f = ff to fl do field_owner.(f) <- r done
  done;
  for g = 1 to img.rows.(M.t_generic_param) do
    let ot, orow = Image.decode M.type_or_method_def (Image.get img M.t_generic_param g "Owner") in
    if ot = M.t_type_def then generics.(orow) <- generics.(orow) + 1
  done;
  Hashtbl.replace extras aname { by_name; method_owner; field_owner; generics };
  images := !images @ [im];
  Logs.info (fun m -> m "assembly %s loaded: %d types, %d methods" aname ntypes img.rows.(M.t_method_def));
  im
