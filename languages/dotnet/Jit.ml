(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Jit.mli *)

module M = Metadata
module S = Signature
module V = Verifier

exception Refused of string

let refuse (why : string) = raise (Refused why)
let sprintf = Printf.sprintf

type mach = Arm | Arm64

type kind = I | R

type site = { srow : int; sat : int; sargs : kind list; sret : kind option }

(* ------------------------------------------------------------------ *)
(* Which methods: static, of int32s only, calling only such methods;
 * with references (refs), instance methods and references too *)
(* ------------------------------------------------------------------ *)

let int32_sig (t : S.t) : bool =
  match t with
  | S.Bool | S.Char | S.I1 | S.U1 | S.I2 | S.U2 | S.I4 | S.U4 -> true
  | _ -> false

(* a parameter's, a local's, a result's kind; [what] if neither *)
let sig_kind (img : Image.t) (refs : bool) (what : string) (t : S.t) : kind =
  if int32_sig t then I
  else match V.of_sig img t with
    | Some (V.Obj _) when refs -> R
    | _ -> refuse what

(* a slot's kind on the stack *)
let vt_kind (refs : bool) (v : V.vt) : kind option =
  match v with
  | V.Int32 | V.Native -> Some I
  | V.Obj _ when refs -> Some R
  | _ -> None

(* the TypeDef a MethodDef is in *)
let owner (img : Image.t) (row : int) : int =
  let rec find c = if c > img.rows.(M.t_type_def) then 1
    else let f, l = Image.range img M.t_type_def c "MethodList" M.t_method_def in
      if row >= f && row <= l then c else find (c + 1) in
  find 1

let generic_class (img : Image.t) (c : int) : bool =
  let rec go g =
    g <= img.rows.(M.t_generic_param)
    && (let ot, orow = Image.decode M.type_or_method_def (Image.get img M.t_generic_param g "Owner") in
        (ot = M.t_type_def && orow = c) || go (g + 1)) in
  go 1

let has_cctor (img : Image.t) (c : int) : bool =
  let f, l = Image.range img M.t_type_def c "MethodList" M.t_method_def in
  let rec go r = r <= l && (Image.string img (Image.get img M.t_method_def r "Name") = ".cctor" || go (r + 1)) in
  go f

let signature (img : Image.t) (row : int) : S.meth =
  S.method_ (Image.blob img (Image.get img M.t_method_def row "Signature"))

let local_sigs (img : Image.t) (body : Image.body) : S.t list =
  if body.locals_token = 0 then []
  else S.locals (Image.blob img (Image.get img M.t_stand_alone_sig (M.token_row body.locals_token) "Signature"))

(* a method's arguments' kinds, `this` first *)
let arg_kinds (img : Image.t) (refs : bool) (row : int) : kind array =
  let sg = signature img row in
  Array.of_list ((if sg.has_this then [ R ] else [])
                 @ List.map (sig_kind img refs "a parameter not an int32") sg.params)

(* a method's own reasons: its signature, its locals, its clauses *)
let own (img : Image.t) (refs : bool) (row : int) : unit =
  let t = M.t_method_def in
  if Image.get img t row "RVA" = 0 then refuse "no body";
  let sg = signature img row in
  if sg.has_this && not refs then refuse "an instance method: this is a reference";
  if sg.generic > 0 then refuse "a generic method";
  if refs && generic_class img (owner img row) then refuse "a generic class's method";
  if sg.has_this && (match V.token_sig img (M.token M.t_type_def (owner img row)) with
      | S.ValueType _ -> true | _ -> false) then refuse "a struct's method: this is a pointer";
  ignore (arg_kinds img refs row);
  if sg.ret <> S.Void then ignore (sig_kind img refs "a result not an int32" sg.ret);
  let body = Image.body img (Image.get img t row "RVA") in
  if body.clauses <> [] then refuse "exception clauses: the interpreter's";
  List.iter (fun l -> ignore (sig_kind img refs "a local not an int32" l)) (local_sigs img body)

let int_kind (k : Il.kind) : bool =
  match k with
  | Il.K_i1 | Il.K_u1 | Il.K_i2 | Il.K_u2 | Il.K_i4 | Il.K_u4 | Il.K_i | Il.K_u -> true
  | _ -> false

(* an instruction the templates have; with references, those of the
 * references inline, and those the interpreter runs for the code
 * (call-outs) *)
let supported (refs : bool) (op : Il.op) : bool =
  match op with
  | Il.Nop | Il.Ldarg _ | Il.Starg _ | Il.Ldloc _ | Il.Stloc _ | Il.Ldc_i4 _ | Il.Dup | Il.Pop
  | Il.Call _ | Il.Ret | Il.Br _ | Il.Brfalse _ | Il.Brtrue _ | Il.Bcmp _ | Il.Switch _
  | Il.Binop (Il.Add | Il.Sub | Il.Mul | Il.Div | Il.Div_un | Il.Rem | Il.Rem_un
             | Il.And | Il.Or | Il.Xor | Il.Shl | Il.Shr | Il.Shr_un)
  | Il.Neg | Il.Not | Il.Ceq | Il.Cgt _ | Il.Clt _
  | Il.Conv ((Il.K_i1 | Il.K_u1 | Il.K_i2 | Il.K_u2 | Il.K_i4 | Il.K_u4 | Il.K_i | Il.K_u), false, _) -> true
  | Il.Ldnull | Il.Ldfld _ | Il.Stfld _ | Il.Ldlen | Il.Prefix _
  | Il.Callvirt _ | Il.Newobj _ | Il.Newarr _ | Il.Ldstr _ | Il.Ldsfld _ | Il.Stsfld _
  | Il.Castclass _ | Il.Isinst _ | Il.Box _ | Il.Unbox_any _ | Il.Throw -> refs
  | Il.Ldelem k | Il.Stelem k -> refs && (int_kind k || k = Il.K_ref)
  | _ -> false

(* a field, in the loaded assembly *)
let field (im : Value.image) (tok : int) : Value.field =
  Types.field_of_token { im; targs = [||]; margs = [||] } tok

(* a call-out's operands and whether it pushes a value; None, done by
 * the code itself *)
let call_out (img : Image.t) (im : Value.image option) (taken : int -> bool) (caller : int) (op : Il.op) :
  (int * bool) option =
  match op with
  | Il.Call tok | Il.Callvirt tok ->
      let m, _ = V.call_sig img tok in
      let callee = M.token_row tok in
      (* a direct call: a static method compiled, whose class is the
       * caller's or has no static constructor to run first *)
      if (match op with Il.Call _ -> true | _ -> false) && M.token_table tok = M.t_method_def
         && not m.has_this && taken callee
         && (owner img callee = owner img caller || not (has_cctor img (owner img callee)))
      then None
      else Some (List.length m.params + (if m.has_this then 1 else 0), m.ret <> S.Void)
  | Il.Newobj tok -> let m, _ = V.call_sig img tok in Some (List.length m.params, true)
  | Il.Ldstr _ | Il.Ldsfld _ -> Some (0, true)
  | Il.Newarr _ | Il.Castclass _ | Il.Isinst _ | Il.Box _ | Il.Unbox_any _ -> Some (1, true)
  | Il.Stsfld _ | Il.Throw -> Some (1, false)
  | Il.Stelem Il.K_ref -> Some (3, false)
  | Il.Stfld tok when (match im with Some im -> Value.is_ref (field im tok).ftype | None -> false) -> Some (2, false)
  | _ -> None

(* the methods the JIT takes: each one's own reasons, its stacks (the
 * verifier's: int32s only, or references), its instructions, and its
 * calls, to methods taken too (until no more is dropped); with
 * references, a call to another method is the interpreter's *)
let choose (img : Image.t) (im : Value.image option) : (int, V.result) Hashtbl.t * (int * string) list =
  let refs = im <> None in
  let taken = Hashtbl.create 16 and refused = ref [] in
  for row = 1 to img.rows.(M.t_method_def) do
    match
      own img refs row;
      let r = V.method_ img row in
      Array.iteri (fun i (s : V.vt list option) ->
          match s with
          | Some s -> List.iter (fun v -> match vt_kind refs v with
              | Some _ -> ()
              | None -> refuse (sprintf "IL_%04x: %s on the stack" r.instrs.(i).at (V.show v))) s
          | None -> ()) (Array.sub r.stacks 0 (Array.length r.instrs));
      Array.iteri (fun i (ins : Il.instr) ->
          if not (supported refs ins.op) then refuse (sprintf "IL_%04x: %s, no template yet" ins.at ins.name);
          let stack = match r.stacks.(i) with Some s -> s | None -> [] in
          let is_ref v = vt_kind refs v = Some R in
          match ins.op, stack with
          | Il.Call tok, _ when not refs && M.token_table tok <> M.t_method_def ->
              refuse (sprintf "IL_%04x: a call into the library" ins.at)
          | (Il.Call _ | Il.Callvirt _ | Il.Newobj _), _ when refs ->
              (match call_out img im (fun _ -> false) row ins.op with
               | Some (n, _) when n > 8 -> refuse (sprintf "IL_%04x: a call of %d arguments" ins.at n)
               | _ -> ())
          | (Il.Bcmp ((Il.Eq | Il.Ne), _, _) | Il.Ceq | Il.Cgt true), b :: a :: _ when is_ref a || is_ref b -> ()
          | (Il.Bcmp _ | Il.Cgt _ | Il.Clt _), b :: a :: _ when is_ref a || is_ref b ->
              refuse (sprintf "IL_%04x: %s of references" ins.at ins.name)
          | (Il.Ldfld tok | Il.Stfld tok), _ ->
              (match im with
               | Some im when (field im tok).fstatic -> refuse (sprintf "IL_%04x: a static field by %s" ins.at ins.name)
               | _ -> ())
          | _ -> ()) r.instrs;
      r
    with
    | r -> Hashtbl.replace taken row r
    | exception Refused why -> if why <> "no body" then refused := (row, why) :: !refused
    | exception V.Bad why -> refused := (row, "not verified: " ^ why) :: !refused
    | exception Types.Load_error why -> refused := (row, "not loaded: " ^ why) :: !refused
  done;
  (* the calls: to a method taken, else the caller is not *)
  let changed = ref (not refs) in
  while !changed do
    changed := false;
    Hashtbl.iter (fun row (r : V.result) ->
        Array.iter (fun (ins : Il.instr) ->
            match ins.op with
            | Il.Call tok when not (Hashtbl.mem taken (M.token_row tok)) && Hashtbl.mem taken row ->
                Hashtbl.remove taken row;
                refused := (row, sprintf "IL_%04x: a call to a method not compiled" ins.at) :: !refused;
                changed := true
            | _ -> ()) r.instrs) (Hashtbl.copy taken)
  done;
  (taken, List.sort compare !refused)

(* ------------------------------------------------------------------ *)
(* The code: a template each instruction *)
(* ------------------------------------------------------------------ *)

(* a method's symbol: its class and its name, what is not a letter or a
 * digit an underscore *)
let symbol (img : Image.t) (row : int) : string =
  let n = Listing.type_name img (M.token M.t_type_def (owner img row))
          ^ "_" ^ Image.string img (Image.get img M.t_method_def row "Name") in
  String.map (fun c -> match c with 'a'..'z' | 'A'..'Z' | '0'..'9' -> c | _ -> '_') n

(* The references' code (arm64, with the assembly loaded: mini-dotnet's
 * own). A reference is the interpreter's value (Value.value: Obj of a
 * store, Str, Null the integer 0), a word of mini-ml's, in a slot of
 * mini-ml's value stack (R26, growing up), where the collector finds
 * it and moves it; the method's words there above its caller's:
 *
 *     R26 -->  +----------------+
 *              | its arguments  |   references: copied by the prologue
 *              | its locals     |
 *              | its slots      |   the stack's, by their depth
 *              +----------------+   R26 at the call: ADD $8n, R26
 *
 * each slot a home in both stacks, the machine's for an int32, this
 * one for a reference, by the verifier's type there. An object's field
 * is read where Value has it: Obj's field 0 the store, its field 1 the
 * bytes (an int32 at the field's offset), its field 2 the references,
 * its field 3 the length of an array (tagged). What the code does not
 * do itself is a call-out, the instruction run by the interpreter
 * (Machine.exec) on its operands: a call, new, a string, a static
 * field, a cast, a reference stored (its write barrier). *)
let store_s = 8 and store_r = 16 and store_len = 24

let method_text (m : mach) (img : Image.t) (syms : (int, string) Hashtbl.t) (row : int) (r : V.result)
    (refs : (Value.image * (int -> bool) * site list ref * int) option) : string =
  let b = Buffer.create 1024 in
  let ins fmt = Printf.ksprintf (fun s -> Buffer.add_string b ("\t" ^ s ^ "\n")) fmt in
  let a64 = m = Arm64 in
  let w = if a64 then 8 else 4 in
  let op s = if a64 then s ^ "W" else s in
  let sym = Hashtbl.find syms row in
  let sg = signature img row in
  let body = Image.body img (Image.get img M.t_method_def row "RVA") in
  let locals = Array.of_list (List.map (sig_kind img (refs <> None) "") (local_sigs img body)) in
  let nlocals = Array.length locals in
  let args = arg_kinds img (refs <> None) row in
  let nargs = Array.length args in
  let depth = Array.fold_left (fun d s -> match s with Some s -> max d (List.length s) | None -> d) 0 r.stacks in
  let nslots = depth + 1 in
  let taken = match refs with Some (_, t, _, _) -> t | None -> (fun _ -> true) in
  let im = match refs with Some (im, _, _, _) -> Some im | None -> None in
  (* the outgoing arguments' room: the most a call passes, 5c's way *)
  let maxargs = Array.fold_left (fun a (ins : Il.instr) -> match ins.op with
      | Il.Call tok when refs = None || call_out img im taken row ins.op = None ->
          let m, _ = V.call_sig img tok in
          max a (List.length m.params)
      | _ -> a) 1 r.instrs in
  let frame = w * (nslots + nlocals) + w * maxargs in
  (* the value stack's words: the slots, the locals, the arguments; none
   * without references *)
  let any_ref = Array.exists (( = ) R) locals || Array.exists (( = ) R) args
                || Array.exists (fun s -> match s with
                    | Some s -> List.exists (fun v -> vt_kind true v = Some R) s | None -> false) r.stacks in
  let nv = if refs <> None && any_ref then nslots + nlocals + nargs else 0 in
  if nv > 32 then refuse "more than 32 words on the value stack";
  let word j = sprintf "%d(R26)" (-8 * (nv - j)) in
  (* the places: a stack slot, a local (autos, below SP), an argument
   * (FP: the first one left there from R0 by the prologue's MOVW) *)
  let slot k = sprintf "s%d-%d(SP)" k (w * (k + 1)) in
  let local i = sprintf "l%d-%d(SP)" i (w * (nslots + i + 1)) in
  let arg i = sprintf "a%d+%d(FP)" i (w * i) in
  let vslot k = word k and vlocal i = word (nslots + i) and varg i = word (nslots + nlocals + i) in
  let label i = sprintf "%s_%d" sym i in
  let targets = Hashtbl.create 8 in
  Array.iter (fun (ins : Il.instr) -> match ins.op with
      | Il.Br t | Il.Brfalse t | Il.Brtrue t | Il.Bcmp (_, _, t) -> Hashtbl.replace targets t ()
      | Il.Switch ts -> Array.iter (fun t -> Hashtbl.replace targets t ()) ts
      | _ -> ()) r.instrs;
  Buffer.add_string b (sprintf "// %s, %d bytes of IL: %d slots, %d locals\n"
                         (Listing.token_name img (M.token M.t_method_def row)) (String.length body.code) nslots nlocals);
  Buffer.add_string b (sprintf "\tTEXT\t%s(SB), 0, $%d\n" sym frame);
  if nargs > 0 && args.(0) = I then ins "MOVW\tR0, %s" (arg 0);
  if nv > 0 then begin
    (* the words above the caller's: each a value (1, null) before the
     * collector can see them; the references given, copied there *)
    ins "ADD\t$%d, R26" (8 * nv);
    ins "MOV\t$1, R1";
    for j = 0 to nv - 1 do ins "MOV\tR1, %s" (word j) done;
    Array.iteri (fun i k ->
        if k = R then
          if i = 0 then ins "MOV\tR0, %s" (varg 0)
          else (ins "MOV\t%s, R1" (arg i); ins "MOV\tR1, %s" (varg i))) args
  end;
  (* the locals zeroed, as .locals init asks (C#'s always does) *)
  if Array.exists (( = ) I) locals then begin
    ins "MOVW\t$0, R1";
    Array.iteri (fun i k -> if k = I then ins "MOVW\tR1, %s" (local i)) locals
  end;
  let return () =
    if nv > 0 then ins "SUB\t$%d, R26" (8 * nv);
    ins "%s" (if a64 then "RETURN" else "RET") in
  Array.iteri (fun i (x : Il.instr) ->
      if Hashtbl.mem targets i then Buffer.add_string b (label i ^ ":\n");
      Buffer.add_string b (sprintf "\t// IL_%04x: %s\n" x.at x.name);
      let d = match r.stacks.(i) with Some s -> List.length s | None -> 0 in
      (* the top's slot is d - 1, the one under it d - 2 *)
      let top = d - 1 in
      (* a slot's kind, before and after *)
      let kind_in s k = match s with
        | Some s -> (match vt_kind true (List.nth s (List.length s - 1 - k)) with Some k -> k | None -> I)
        | None -> I in
      let before k = kind_in r.stacks.(i) k in
      let after k = if i + 1 < Array.length r.stacks then kind_in r.stacks.(i + 1) k else I in
      (* a value moved: from a place to a place, of its kind *)
      let move k (src_i, src_r) (dst_i, dst_r) =
        if k = I then (ins "MOVW\t%s, R1" src_i; ins "MOVW\tR1, %s" dst_i)
        else (ins "MOV\t%s, R1" src_r; ins "MOV\tR1, %s" dst_r) in
      let pair f =
        ins "MOVW\t%s, R1" (slot (top - 1));
        ins "MOVW\t%s, R2" (slot top);
        f ();
        ins "MOVW\tR1, %s" (slot (top - 1)) in
      let compare (c : Il.cmp) (un : bool) : string =
        match c, un with
        | Il.Eq, _ -> "EQ" | Il.Ne, _ -> "NE"
        | Il.Lt, false -> "LT" | Il.Le, false -> "LE" | Il.Gt, false -> "GT" | Il.Ge, false -> "GE"
        | Il.Lt, true -> "LO" | Il.Le, true -> "LS" | Il.Gt, true -> "HI" | Il.Ge, true -> "HS" in
      (* arm's MOVW conditional; arm64 has no condition on a move (its
       * CSET mini-ld does not encode): a branch over the 0 *)
      let set_bool cc =
        if a64 then (ins "MOVW\t$1, R3"; ins "B%s\t2(PC)" cc; ins "MOVW\t$0, R3")
        else (ins "MOVW\t$0, R3"; ins "MOVW.%s\t$1, R3" cc);
        ins "MOVW\tR3, %s" (slot (top - 1)) in
      (* two references the same object: the same word, or two blocks
       * of the same thing (Obj's store, Str's string), as Arith compares
       * them; R3 1 if so, else 0 *)
      let ref_eq () =
        let fin = sprintf "%s_%d_eq" sym i in
        ins "MOV\t%s, R1" (vslot (top - 1));
        ins "MOV\t%s, R2" (vslot top);
        ins "MOV\t$1, R3";
        ins "CMP\tR2, R1";
        ins "BEQ\t%s" fin;
        ins "MOV\t$0, R3";
        ins "CMP\t$1, R1";
        ins "BEQ\t%s" fin;
        ins "CMP\t$1, R2";
        ins "BEQ\t%s" fin;
        ins "MOV\t0(R1), R1";
        ins "MOV\t0(R2), R2";
        ins "CMP\tR2, R1";
        ins "BNE\t%s" fin;
        ins "MOV\t$1, R3";
        Buffer.add_string b (fin ^ ":\n") in
      (* an object's store in R1, from a reference in a slot: null
       * thrown as NullReferenceException *)
      let store_of k =
        ins "MOV\t%s, R1" (vslot k);
        ins "CMP\t$1, R1";
        ins "BNE\t2(PC)";
        ins "BL\tjit_null(SB)";
        ins "MOV\t0(R1), R1" in
      (* an array's element: its store in R1, the index (slot k) in R2,
       * checked against the length; R1 then the element's address, in
       * the bytes or the references *)
      let element k (size : int) (is_ref : bool) =
        store_of (k - 1);
        ins "MOVW\t%s, R2" (slot k);
        ins "MOV\t%d(R1), R3" store_len;
        ins "ASR\t$1, R3";
        ins "CMP\tR3, R2";
        ins "BLO\t2(PC)";
        ins "BL\tjit_range(SB)";
        ins "MOV\t%d(R1), R1" (if is_ref then store_r else store_s);
        let sh = match size with 1 -> 0 | 2 -> 1 | 4 -> 2 | _ -> 3 in
        if sh > 0 then ins "LSL\t$%d, R2" sh;
        ins "ADD\tR2, R1" in
      let load_of (t : Value.typ) = match t with
        | Value.T_bool | Value.T_u1 -> "MOVBU" | Value.T_i1 -> "MOVB"
        | Value.T_char | Value.T_u2 -> "MOVHU" | Value.T_i2 -> "MOVH" | _ -> "MOVW" in
      let store_as (t : Value.typ) = match t with
        | Value.T_bool | Value.T_u1 | Value.T_i1 -> "MOVB"
        | Value.T_char | Value.T_u2 | Value.T_i2 -> "MOVH" | _ -> "MOVW" in
      let kind_typ (k : Il.kind) : Value.typ = match k with
        | Il.K_i1 -> Value.T_i1 | Il.K_u1 -> Value.T_u1 | Il.K_i2 -> Value.T_i2
        | Il.K_u2 -> Value.T_u2 | _ -> Value.T_i4 in
      match refs, x.op with
      | Some _, _ when r.stacks.(i) = None -> ()
      | Some (_, _, sites, base), _ when call_out img im taken row x.op <> None ->
          (* the instruction run by the interpreter: its operands, the
           * bottom first, as values of mini-ml's (an int32 tagged), in
           * R2...; the call-out's number in R1 *)
          let n, pushes = match call_out img im taken row x.op with Some p -> p | None -> assert false in
          let kinds = List.init n (fun j -> before (top - n + 1 + j)) in
          let ret = if pushes then Some (after (top - n + 1)) else None in
          let number = base + List.length !sites in
          sites := !sites @ [ { srow = row; sat = i; sargs = kinds; sret = ret } ];
          ins "MOV\t$%d, R1" (2 * number + 1);
          List.iteri (fun j k ->
              let s = top - n + 1 + j in
              if k = I then (ins "MOVW\t%s, R%d" (slot s) (j + 2); ins "LSL\t$1, R%d" (j + 2); ins "ORR\t$1, R%d" (j + 2))
              else ins "MOV\t%s, R%d" (vslot s) (j + 2)) kinds;
          ins "BL\tjit_out%d(SB)" n;
          (match ret with
           | Some I -> ins "ASR\t$1, R0"; ins "MOVW\tR0, %s" (slot (top - n + 1))
           | Some R -> ins "MOV\tR0, %s" (vslot (top - n + 1))
           | None -> ())
      | _, Il.Nop | _, Il.Prefix _ -> ()
      | _, Il.Ldarg a -> move args.(a) (arg a, varg a) (slot (top + 1), vslot (top + 1))
      | _, Il.Starg a -> move args.(a) (slot top, vslot top) (arg a, varg a)
      | _, Il.Ldloc l -> move locals.(l) (local l, vlocal l) (slot (top + 1), vslot (top + 1))
      | _, Il.Stloc l -> move locals.(l) (slot top, vslot top) (local l, vlocal l)
      | _, Il.Ldc_i4 n -> ins "MOVW\t$%ld, R1" n; ins "MOVW\tR1, %s" (slot (top + 1))
      | _, Il.Ldnull -> ins "MOV\t$1, R1"; ins "MOV\tR1, %s" (vslot (top + 1))
      | _, Il.Dup -> move (before top) (slot top, vslot top) (slot (top + 1), vslot (top + 1))
      | _, Il.Pop -> ()
      | Some (im, _, _, _), (Il.Ldfld tok | Il.Stfld tok) ->
          let fd = field im tok in
          let is_ref = Value.is_ref fd.ftype in
          (match x.op with
           | Il.Ldfld _ ->
               store_of top;
               if is_ref then (ins "MOV\t%d(R1), R1" store_r; ins "MOV\t%d(R1), R1" (8 * fd.roff); ins "MOV\tR1, %s" (vslot top))
               else (ins "MOV\t%d(R1), R1" store_s; ins "%s\t%d(R1), R1" (load_of fd.ftype) fd.off; ins "MOVW\tR1, %s" (slot top))
           | _ when is_ref -> assert false
           | _ ->
               store_of (top - 1);
               ins "MOV\t%d(R1), R1" store_s;
               ins "MOVW\t%s, R2" (slot top);
               ins "%s\tR2, %d(R1)" (store_as fd.ftype) fd.off)
      | Some _, Il.Ldlen ->
          store_of top;
          ins "MOV\t%d(R1), R1" store_len;
          ins "ASR\t$1, R1";
          ins "MOVW\tR1, %s" (slot top)
      | Some _, Il.Ldelem Il.K_ref ->
          element top 8 true;
          ins "MOV\t0(R1), R1";
          ins "MOV\tR1, %s" (vslot (top - 1))
      | Some _, Il.Ldelem k ->
          let t = kind_typ k in
          element top (Value.scalar_size t) false;
          ins "%s\t0(R1), R1" (load_of t);
          ins "MOVW\tR1, %s" (slot (top - 1))
      | Some _, Il.Stelem k ->
          let t = kind_typ k in
          element (top - 1) (Value.scalar_size t) false;
          ins "MOVW\t%s, R3" (slot top);
          ins "%s\tR3, 0(R1)" (store_as t)
      | _, Il.Binop o ->
          pair (fun () ->
              match o with
              | Il.Add -> ins "%s\tR2, R1" (op "ADD")
              | Il.Sub -> ins "%s\tR2, R1" (op "SUB")
              | Il.Mul -> ins "%s\tR2, R1" (op "MUL")
              | Il.And -> ins "%s\tR2, R1" (op "AND")
              | Il.Or -> ins "%s\tR2, R1" (op "ORR")
              | Il.Xor -> ins "%s\tR2, R1" (op "EOR")
              (* (.NET's shifts take the count's low 5 bits) *)
              | Il.Shl | Il.Shr | Il.Shr_un ->
                  ins "%s\t$31, R2" (op "AND");
                  ins "%s\tR2, R1" (match o, m with
                      | Il.Shl, Arm -> "SLL" | Il.Shr, Arm -> "SRA" | _, Arm -> "SRL"
                      | Il.Shl, Arm64 -> "LSLW" | Il.Shr, Arm64 -> "ASRW" | _, Arm64 -> "LSRW")
              | Il.Div | Il.Div_un | Il.Rem | Il.Rem_un ->
                  (* by zero: the runtime's DivideByZeroException *)
                  ins "%s\t$0, R2" (op "CMP");
                  ins "BNE\t2(PC)";
                  ins "BL\tjit_divide_by_zero(SB)";
                  ins "%s\tR2, R1" (match o, m with
                      | Il.Div, Arm -> "DIV" | Il.Div_un, Arm -> "DIVU" | Il.Rem, Arm -> "MOD" | _, Arm -> "MODU"
                      | Il.Div, Arm64 -> "SDIVW" | Il.Div_un, Arm64 -> "UDIVW" | Il.Rem, Arm64 -> "REMW"
                      | _, Arm64 -> "UREMW")
              | _ -> assert false)
      | _, Il.Neg ->
          ins "MOVW\t%s, R1" (slot top);
          if a64 then ins "NEGW\tR1, R1" else ins "RSB\t$0, R1, R1";
          ins "MOVW\tR1, %s" (slot top)
      | _, Il.Not -> ins "MOVW\t%s, R1" (slot top); ins "%s\tR1, R1" (op "MVN"); ins "MOVW\tR1, %s" (slot top)
      | _, (Il.Ceq | Il.Cgt true) when before top = R || before (top - 1) = R ->
          (* (cgt.un of references: C#'s x != null) *)
          ref_eq ();
          if x.op <> Il.Ceq then ins "EOR\t$1, R3";
          ins "MOVW\tR3, %s" (slot (top - 1))
      | _, (Il.Ceq | Il.Cgt _ | Il.Clt _) ->
          ins "MOVW\t%s, R1" (slot (top - 1));
          ins "MOVW\t%s, R2" (slot top);
          ins "%s\tR2, R1" (op "CMP");
          set_bool (match x.op with
              | Il.Ceq -> "EQ" | Il.Cgt un -> compare Il.Gt un | Il.Clt un -> compare Il.Lt un | _ -> assert false)
      | _, Il.Conv (k, _, _) ->
          ins "MOVW\t%s, R1" (slot top);
          (match k, m with
           | Il.K_i1, Arm -> ins "SLL\t$24, R1"; ins "SRA\t$24, R1"
           | Il.K_u1, Arm -> ins "AND\t$255, R1"
           | Il.K_i2, Arm -> ins "SLL\t$16, R1"; ins "SRA\t$16, R1"
           | Il.K_u2, Arm -> ins "SLL\t$16, R1"; ins "SRL\t$16, R1"
           | Il.K_i1, Arm64 -> ins "SXTBW\tR1, R1"
           | Il.K_u1, Arm64 -> ins "UXTBW\tR1, R1"
           | Il.K_i2, Arm64 -> ins "SXTHW\tR1, R1"
           | Il.K_u2, Arm64 -> ins "UXTHW\tR1, R1"
           | _ -> ());
          ins "MOVW\tR1, %s" (slot top)
      | _, Il.Br t -> ins "B\t%s" (label t)
      | _, (Il.Brfalse t | Il.Brtrue t) when before top = R ->
          ins "MOV\t%s, R1" (vslot top);
          ins "CMP\t$1, R1";
          ins "%s\t%s" (match x.op with Il.Brtrue _ -> "BNE" | _ -> "BEQ") (label t)
      | _, (Il.Brfalse t | Il.Brtrue t) ->
          ins "MOVW\t%s, R1" (slot top);
          ins "%s\t$0, R1" (op "CMP");
          ins "%s\t%s" (match x.op with Il.Brtrue _ -> "BNE" | _ -> "BEQ") (label t)
      | _, Il.Bcmp (c, _, t) when before top = R || before (top - 1) = R ->
          ref_eq ();
          ins "CMP\t$0, R3";
          ins "%s\t%s" (if c = Il.Eq then "BNE" else "BEQ") (label t)
      | _, Il.Bcmp (c, un, t) ->
          ins "MOVW\t%s, R1" (slot (top - 1));
          ins "MOVW\t%s, R2" (slot top);
          ins "%s\tR2, R1" (op "CMP");
          ins "B%s\t%s" (compare c un) (label t)
      | _, Il.Switch ts ->
          ins "MOVW\t%s, R1" (slot top);
          Array.iteri (fun k t -> ins "%s\t$%d, R1" (op "CMP") k; ins "BEQ\t%s" (label t)) ts
      | _, Il.Call tok ->
          (* 5c's and 7c's call: the first argument in R0, the i-th at
           * w(i+1) on the stack; the result in R0 *)
          let callee = M.token_row tok in
          let ks = arg_kinds img (refs <> None) callee in
          let n = Array.length ks in
          for k = n - 1 downto 1 do
            let s = top - n + 1 + k in
            if ks.(k) = I then (ins "MOVW\t%s, R1" (slot s); ins "MOVW\tR1, %d(%s)" (w + w * k) (if a64 then "R31" else "R13"))
            else (ins "MOV\t%s, R1" (vslot s); ins "MOV\tR1, %d(R31)" (w + w * k))
          done;
          if n > 0 then
            if ks.(0) = I then ins "MOVW\t%s, R0" (slot (top - n + 1)) else ins "MOV\t%s, R0" (vslot (top - n + 1));
          ins "BL\t%s(SB)" (Hashtbl.find syms callee);
          let sg' = signature img callee in
          if sg'.ret <> S.Void then
            if sig_kind img (refs <> None) "" sg'.ret = I then ins "MOVW\tR0, %s" (slot (top - n + 1))
            else ins "MOV\tR0, %s" (vslot (top - n + 1))
      | _, Il.Ret ->
          if sg.ret <> S.Void then
            if before top = I then ins "MOVW\t%s, R0" (slot top) else ins "MOV\t%s, R0" (vslot top);
          return ()
      | _ -> assert false) r.instrs;
  Buffer.contents b

(* the methods' symbols, by their rows *)
let symbols (img : Image.t) (taken : (int, V.result) Hashtbl.t) : int list * (int, string) Hashtbl.t =
  let syms = Hashtbl.create 16 and used = Hashtbl.create 16 in
  let rows = List.sort compare (Hashtbl.fold (fun row _ acc -> row :: acc) taken []) in
  List.iter (fun row ->
      let s = symbol img row in
      let s = if Hashtbl.mem used s then sprintf "%s_%d" s row else s in
      Hashtbl.replace used s ();
      Hashtbl.replace syms row s) rows;
  (rows, syms)

exception Dropped of int * string

(* each method's text, its call-outs numbered from [base]; a method
 * refused only now (its frame too big) is dropped with its callers,
 * and all again *)
let texts (m : mach) (img : Image.t) (im : Value.image option) (base : int) :
  int list * (int, string) Hashtbl.t * string * site list * (int * string) list =
  let taken, refused = choose img im in
  let refused = ref refused in
  let rec go () =
    let rows, syms = symbols img taken in
    let sites = ref [] in
    let b = Buffer.create 4096 in
    match
      List.iter (fun row ->
          let refs = match im with
            | Some im -> Some (im, (fun r -> Hashtbl.mem taken r), sites, base)
            | None -> None in
          match method_text m img syms row (Hashtbl.find taken row) refs with
          | s -> Buffer.add_string b s
          | exception Refused why -> raise (Dropped (row, why))) rows
    with
    | () -> (rows, syms, Buffer.contents b, !sites, List.sort compare !refused)
    | exception Dropped (row, why) ->
        Hashtbl.remove taken row;
        refused := (row, why) :: !refused;
        (* (its direct callers: those that call it by BL) *)
        Hashtbl.iter (fun caller (r : V.result) ->
            if Array.exists (fun (ins : Il.instr) -> match ins.op with
                | Il.Call tok -> M.token_table tok = M.t_method_def && M.token_row tok = row
                | _ -> false) r.instrs
            then (Hashtbl.remove taken caller;
                  refused := (caller, "a call to a method not compiled") :: !refused))
          (Hashtbl.copy taken);
        go () in
  go ()

let assembly (m : mach) (img : Image.t) (im : Value.image option) : string * int * (int * string) list =
  let im = if m = Arm then None else im in
  let rows, _, text, _, refused = texts m img im 0 in
  (text, List.length rows, refused)

(* ------------------------------------------------------------------ *)
(* In mini-dotnet: each method's entry an ML function *)
(* ------------------------------------------------------------------ *)

(* An entry, as mini-ml calls a closure of one argument (Gen: the
 * closure in R0, its argument in R1, the result in R0): the argument
 * an array of the method's arguments, values of mini-ml's (an int32 a
 * tagged int); each put in 7c's places, an int32 untagged, the method
 * called, its result tagged (2n + 1), a reference as it is. The value
 * stack's top (R26) is the caller's, which the method raises if it
 * holds references. *)
let entry (img : Image.t) (syms : (int, string) Hashtbl.t) (row : int) : string =
  let b = Buffer.create 256 in
  let ins fmt = Printf.ksprintf (fun s -> Buffer.add_string b ("\t" ^ s ^ "\n")) fmt in
  let sym = Hashtbl.find syms row in
  let sg = signature img row in
  let ks = arg_kinds img true row in
  let n = Array.length ks in
  Buffer.add_string b (sprintf "\tTEXT\t%s_entry(SB), 0, $%d\n" sym (8 * (n + 1)));
  for k = n - 1 downto 1 do
    ins "MOV\t%d(R1), R2" (8 * k);
    if ks.(k) = I then (ins "ASR\t$1, R2"; ins "MOVW\tR2, %d(R31)" (8 + 8 * k))
    else ins "MOV\tR2, %d(R31)" (8 + 8 * k)
  done;
  if n > 0 then (ins "MOV\t0(R1), R0"; if ks.(0) = I then ins "ASR\t$1, R0");
  ins "BL\t%s(SB)" sym;
  if sg.ret = S.Void then ins "MOV\t$1, R0"
  else if sig_kind img true "" sg.ret = I then (ins "LSL\t$1, R0"; ins "ORR\t$1, R0");
  ins "RETURN";
  Buffer.contents b

let outs = 8

let program (im : Value.image) ~(base : int) ~(throws : (string * int) list) ~(out : int array) :
  string * (int * string) list * site list =
  let img = im.img in
  let rows, syms, text, sites, _ = texts Arm64 img (Some im) base in
  let b = Buffer.create 4096 in
  Buffer.add_string b text;
  List.iter (fun row -> Buffer.add_string b (entry img syms row)) rows;
  (* the runtime's: an ML function's static closure at an address,
   * called by its n-ary code (field 1) with the code's link kept: a
   * throw's of unit, which raises and so does not come back; a
   * call-out's of the number in R1 and the operands *)
  List.iter (fun (name, addr) ->
      Buffer.add_string b (sprintf "\tTEXT\t%s(SB), $-8\n\tMOV\t$%d, R0\n\tMOV\t$1, R1\n\tMOV\t8(R0), R16\n\tB\t(R16)\n" name addr))
    throws;
  Array.iteri (fun n addr ->
      Buffer.add_string b (sprintf "\tTEXT\tjit_out%d(SB), $-8\n\tMOV\t$%d, R0\n\tMOV\t8(R0), R16\n\tB\t(R16)\n" n addr))
    out;
  (Buffer.contents b, List.map (fun row -> (row, Hashtbl.find syms row ^ "_entry")) rows, sites)
