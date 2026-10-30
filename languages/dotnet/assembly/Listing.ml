(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Listing.mli *)

module M = Metadata

let sprintf = Printf.sprintf

(* the TypeDef row enclosing a nested one, 0 if none (NestedClass is
 * sorted by its first column, but small: searched) *)
let enclosing (img : Image.t) (row : int) : int =
  let t = img.tables.(M.t_nested_class) in
  let rec go i =
    if i >= Array.length t then 0
    else if t.(i).(0) = row then t.(i).(1)
    else go (i + 1) in
  go 1

let dotted (ns : string) (n : string) : string = if ns = "" then n else ns ^ "." ^ n

let rec type_name (img : Image.t) (tok : int) : string =
  let row = M.token_row tok in
  match M.token_table tok with
  | t when t = M.t_type_def ->
      let n = dotted (Image.string img (Image.get img t row "TypeNamespace"))
                (Image.string img (Image.get img t row "TypeName")) in
      let outer = enclosing img row in
      if outer = 0 then n else type_name img (M.token M.t_type_def outer) ^ "/" ^ n
  | t when t = M.t_type_ref ->
      let n = dotted (Image.string img (Image.get img t row "TypeNamespace"))
                (Image.string img (Image.get img t row "TypeName")) in
      let st, sr = Image.decode M.resolution_scope (Image.get img t row "ResolutionScope") in
      if st = M.t_assembly_ref then
        "[" ^ Image.string img (Image.get img st sr "Name") ^ "]" ^ n
      else if st = M.t_type_ref then type_name img (M.token st sr) ^ "/" ^ n
      else n
  | t when t = M.t_type_spec ->
      Signature.show (type_name img) (Signature.type_spec (Image.blob img (Image.get img t row "Signature")))
  | t -> sprintf "<token 0x%08x of %s>" tok (M.name t)

(* a MethodDef's or a Field's type: the TypeDef whose range holds it *)
let owner (img : Image.t) (table : int) (row : int) : int =
  let col = if table = M.t_field then "FieldList" else "MethodList" in
  let n = img.rows.(M.t_type_def) in
  let rec go r = if r > n then 0
    else let first, last = Image.range img M.t_type_def r col table in
      if row >= first && row <= last then r else go (r + 1) in
  go 1

let rec token_name (img : Image.t) (tok : int) : string =
  let name = type_name img in
  let row = M.token_row tok in
  match M.token_table tok with
  | t when t = M.t_method_def ->
      let m = Signature.method_ (Image.blob img (Image.get img t row "Signature")) in
      let cls = name (M.token M.t_type_def (owner img t row)) in
      Signature.show_meth name (cls ^ "::" ^ Image.string img (Image.get img t row "Name")) m
  | t when t = M.t_field ->
      let ty = Signature.field (Image.blob img (Image.get img t row "Signature")) in
      let cls = name (M.token M.t_type_def (owner img t row)) in
      Signature.show name ty ^ " " ^ cls ^ "::" ^ Image.string img (Image.get img t row "Name")
  | t when t = M.t_member_ref ->
      let pt, pr = Image.decode M.member_ref_parent (Image.get img t row "Class") in
      let cls = if pt = M.t_method_def then "" else name (M.token pt pr) in
      let n = Image.string img (Image.get img t row "Name") in
      let sg = Image.blob img (Image.get img t row "Signature") in
      if String.length sg > 0 && sg.[0] = '\006' then
        Signature.show name (Signature.field sg) ^ " " ^ cls ^ "::" ^ n
      else Signature.show_meth name (cls ^ "::" ^ n) (Signature.method_ sg)
  | t when t = M.t_method_spec ->
      let mt, mr = Image.decode M.method_def_or_ref (Image.get img t row "Method") in
      let args = Signature.method_spec (Image.blob img (Image.get img t row "Instantiation")) in
      (* (the method, then its type arguments: ildasm puts them after
       * the name, here after the whole) *)
      token_name img (M.token mt mr)
      ^ " with <" ^ String.concat ", " (List.map (Signature.show name) args) ^ ">"
  | t when t = M.t_user_string -> sprintf "%S" (Image.user_string img row)
  | t when t = M.t_stand_alone_sig ->
      let sg = Image.blob img (Image.get img t row "Signature") in
      if String.length sg > 0 && sg.[0] = '\007' then
        "locals (" ^ String.concat ", " (List.map (Signature.show name) (Signature.locals sg)) ^ ")"
      else Signature.show_meth name "" (Signature.method_ sg)
  | _ -> name tok

(* -tables *)

let tables (img : Image.t) : string =
  let b = Buffer.create 4096 in
  Buffer.add_string b (sprintf "metadata %s\n" img.version);
  for t = 0 to M.count - 1 do
    let n = img.rows.(t) in
    if n > 0 then begin
      let cols = M.columns t in
      Buffer.add_string b (sprintf "\n0x%02X %s, %d row%s: %s\n" t (M.name t) n
                             (if n = 1 then "" else "s")
                             (String.concat " " (Array.to_list (Array.map fst cols))));
      for r = 1 to n do
        let v = img.tables.(t).(r) in
        let cell i (_, k) =
          let x = v.(i) in
          match (k : M.column) with
          | U8 | U16 | U32 -> sprintf "0x%x" x
          | String -> sprintf "%S" (Image.string img x)
          | Guid -> if x = 0 then "-" else sprintf "guid#%d" x
          | Blob -> sprintf "blob#%x" x
          | Table tt -> sprintf "%s#%d" (M.name tt) x
          | Coded c ->
              let ct, cr = Image.decode c x in
              if ct < 0 then "-" else sprintf "%s#%d" (M.name ct) cr in
        Buffer.add_string b (sprintf "  %3d  %s\n" r
                               (String.concat "  " (Array.to_list (Array.mapi cell cols))))
      done
    end
  done;
  Buffer.contents b

(* -S *)

let operand (img : Image.t) (instrs : Il.instr array) (op : Il.op) : string =
  let lbl i = if i < Array.length instrs then sprintf "IL_%04x" instrs.(i).at else "IL_end" in
  let name t = try token_name img t with _ -> sprintf "0x%08x" t in
  match op with
  | Ldarg n | Ldarga n | Starg n | Ldloc n | Ldloca n | Stloc n -> string_of_int n
  | Ldc_i4 v -> Int32.to_string v
  | Ldc_i8 v -> Int64.to_string v
  | Ldc_r f -> sprintf "%.17g" f
  | Br t | Brfalse t | Brtrue t | Bcmp (_, _, t) | Leave t -> lbl t
  | Switch ts -> "(" ^ String.concat ", " (Array.to_list (Array.map lbl ts)) ^ ")"
  | Jmp t | Call t | Calli t | Callvirt t | Cpobj t | Ldobj t | Stobj t | Ldstr t
  | Newobj t | Castclass t | Isinst t | Unbox t | Unbox_any t | Box t
  | Ldfld t | Ldflda t | Stfld t | Ldsfld t | Ldsflda t | Stsfld t
  | Newarr t | Ldelema t | Ldelem_any t | Stelem_any t | Refanyval t | Mkrefany t
  | Ldtoken t | Ldftn t | Ldvirtftn t | Initobj t | Sizeof t | Constrained t -> name t
  | _ -> ""

let method_listing (b : Buffer.t) (img : Image.t) (row : int) : unit =
  let t = M.t_method_def in
  let name = Image.string img (Image.get img t row "Name") in
  let m = Signature.method_ (Image.blob img (Image.get img t row "Signature")) in
  let flags = Image.get img t row "Flags" in
  let rva = Image.get img t row "RVA" in
  let attrs =
    (if flags land 0x0010 <> 0 then "static " else "")
    ^ (if flags land 0x0040 <> 0 then "virtual " else "")
    ^ (if flags land 0x0400 <> 0 then "abstract " else "") in
  Buffer.add_string b (sprintf "  .method %s%s" attrs (Signature.show_meth (type_name img) name m));
  if rva = 0 then Buffer.add_string b
      (if Image.get img t row "ImplFlags" land 0x3 = 0x3 then "   // runtime\n" else "   // no body\n")
  else begin
    let body = Image.body img rva in
    Buffer.add_string b (sprintf "   // RVA 0x%x, %d bytes\n  {\n" rva (String.length body.code));
    if M.token t row = img.entry_point then Buffer.add_string b "    .entrypoint\n";
    Buffer.add_string b (sprintf "    .maxstack %d\n" body.max_stack);
    if body.locals_token <> 0 then
      Buffer.add_string b (sprintf "    .%s\n" (token_name img body.locals_token));
    let instrs = Il.decode body.code in
    Array.iter (fun (ins : Il.instr) ->
        (* (ldarg.0, ldc.i4.m1: the operand in the name) *)
        let implicit = match String.rindex_opt ins.name '.' with
          | Some i -> (match String.sub ins.name (i + 1) (String.length ins.name - i - 1) with
              | "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "m1" -> true
              | _ -> false)
          | None -> false in
        let o = if implicit then "" else operand img instrs ins.op in
        Buffer.add_string b (sprintf "    IL_%04x: %s%s\n" ins.at ins.name (if o = "" then "" else " " ^ o)))
      instrs;
    List.iter (fun (c : Image.clause) ->
        let what = match c.kind with
          | 0 -> "catch " ^ (try token_name img c.class_token with _ -> "?")
          | 1 -> "filter" | 2 -> "finally" | _ -> "fault" in
        Buffer.add_string b (sprintf "    .try IL_%04x to IL_%04x %s handler IL_%04x to IL_%04x\n"
                               c.try_start c.try_end what c.handler_start c.handler_end))
      body.clauses;
    Buffer.add_string b "  }\n"
  end

let listing (img : Image.t) : string =
  let b = Buffer.create 8192 in
  let asm = if img.rows.(M.t_assembly) > 0
    then Image.string img (Image.get img M.t_assembly 1 "Name") else "(a module)" in
  Buffer.add_string b (sprintf ".assembly %s\n" asm);
  for r = 1 to img.rows.(M.t_assembly_ref) do
    Buffer.add_string b (sprintf ".assembly extern %s\n"
                           (Image.string img (Image.get img M.t_assembly_ref r "Name")))
  done;
  for r = 1 to img.rows.(M.t_type_def) do
    let t = M.t_type_def in
    let flags = Image.get img t r "Flags" in
    let et, er = Image.decode M.type_def_or_ref (Image.get img t r "Extends") in
    let ifaces = ref [] in
    for i = img.rows.(M.t_interface_impl) downto 1 do
      if Image.get img M.t_interface_impl i "Class" = r then
        let it, ir = Image.decode M.type_def_or_ref (Image.get img M.t_interface_impl i "Interface") in
        ifaces := type_name img (M.token it ir) :: !ifaces
    done;
    Buffer.add_string b (sprintf "\n.class %s%s%s%s\n{\n"
                           (if flags land 0x20 <> 0 then "interface " else "")
                           (type_name img (M.token t r))
                           (if et < 0 then "" else " extends " ^ type_name img (M.token et er))
                           (if !ifaces = [] then "" else " implements " ^ String.concat ", " !ifaces));
    let ff, fl = Image.range img t r "FieldList" M.t_field in
    for f = ff to fl do
      let fflags = Image.get img M.t_field f "Flags" in
      let ty = Signature.field (Image.blob img (Image.get img M.t_field f "Signature")) in
      Buffer.add_string b (sprintf "  .field %s%s %s\n"
                             (if fflags land 0x10 <> 0 then "static " else "")
                             (Signature.show (type_name img) ty)
                             (Image.string img (Image.get img M.t_field f "Name")))
    done;
    let mf, ml = Image.range img t r "MethodList" M.t_method_def in
    for m = mf to ml do method_listing b img m done;
    Buffer.add_string b "}\n"
  done;
  Buffer.contents b

let sizes (img : Image.t) : int * int * int =
  let il = ref 0 in
  for m = 1 to img.rows.(M.t_method_def) do
    let rva = Image.get img M.t_method_def m "RVA" in
    if rva <> 0 then begin
      let body = Image.body img rva in
      ignore (Il.decode body.code);
      il := !il + String.length body.code
    end
  done;
  (img.rows.(M.t_type_def), img.rows.(M.t_method_def), !il)
