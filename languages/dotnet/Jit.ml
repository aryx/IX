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

type form = Word | Addr | Made of int

(* what a call-out does: an instruction run by the interpreter; or for
 * a try (clause c, by its index in the method's), its frame pushed for
 * the first pass and popped, an exception caught or let go, raised
 * again (a finally's end), rethrown (a catch's rethrow); a struct
 * copied (its value loaded: Machine's copy_value), a struct local's
 * first value (its zeros: .locals init) *)
type op = Run | Enter of int | Leave_try | Catch of int | Reraise | Rethrow | Copy | Init of int

type site = { srow : int; sat : int; sargs : kind list; sform : form list; sret : kind option; sop : op }

(* a method's clauses, by instructions' indexes: (kind, try's start,
 * end, handler's start, end); 0 catch, 2 finally *)
let clauses (img : Image.t) (row : int) (r : V.result) : (int * int * int * int * int) array =
  let body = Image.body img (Image.get img M.t_method_def row "RVA") in
  let ix = Il.index r.instrs in
  Array.of_list (List.map (fun (c : Image.clause) ->
      (c.kind, ix c.try_start, ix c.try_end, ix c.handler_start, ix c.handler_end)) body.clauses)

(* what an address on the stack names (ldloca, ldarga), or a value
 * the interpreter makes at the call-out that takes it (ldftn's, at
 * that instruction) *)
type place = Local of int | Arg of int | Ftn of int

(* ------------------------------------------------------------------ *)
(* Which methods: static, of int32s only, calling only such methods;
 * with references (refs), instance methods and references too *)
(* ------------------------------------------------------------------ *)

let int32_sig (t : S.t) : bool =
  match t with
  | S.Bool | S.Char | S.I1 | S.U1 | S.I2 | S.U2 | S.I4 | S.U4 -> true
  | _ -> false

(* Generics: a method of a generic class, or a generic method, is
 * compiled for each instantiation, its type arguments here while it is
 * (the class's, the method's: Types.ctx_of's); a T an int32 there, or
 * a reference, as the instantiation has it *)
let instance : (Value.typ array * Value.typ array) option ref = ref None

let typ_kind (t : Value.typ) : kind option =
  match t with
  | Value.T_bool | Value.T_char | Value.T_i1 | Value.T_u1 | Value.T_i2 | Value.T_u2
  | Value.T_i4 | Value.T_u4 | Value.T_i | Value.T_u -> Some I
  | Value.T_class _ | Value.T_array _ -> Some R
  | _ -> None

let gen_kind (t : S.t) : kind option =
  match t, !instance with
  | S.Var n, Some (ta, _) when n < Array.length ta -> typ_kind ta.(n)
  | S.MVar n, Some (_, ma) when n < Array.length ma -> typ_kind ma.(n)
  | _ -> None

(* a parameter's, a local's, a result's kind; [what] if neither *)
let sig_kind (img : Image.t) (refs : bool) (what : string) (t : S.t) : kind =
  if int32_sig t then I
  else match V.of_sig img t with
    | Some (V.Obj _ | V.Ptr _ | V.Value _) when refs -> R
    | Some (V.Gen g) when refs -> (match gen_kind g with Some k -> k | None -> refuse what)
    | _ -> refuse what

(* a slot's kind on the stack *)
let vt_kind (refs : bool) (v : V.vt) : kind option =
  match v with
  | V.Int32 | V.Native -> Some I
  | V.Obj _ when refs -> Some R
  (* (an address: the interpreter's Ptr, opaque, a parameter's ref or
   * out; a local's, ldloca's, is none at run time: addresses) *)
  | V.Ptr _ when refs -> Some R
  (* (a struct: the interpreter's Vt, copied where the IL copies it) *)
  | V.Value _ when refs -> Some R
  | V.Gen g when refs -> gen_kind g
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
  if !instance = None && sg.generic > 0 then refuse "a generic method";
  if !instance = None && refs && generic_class img (owner img row) then refuse "a generic class's method";
  if sg.has_this && not refs && (match V.token_sig img (M.token M.t_type_def (owner img row)) with
      | S.ValueType _ -> true | _ -> false) then refuse "a struct's method: this is a pointer";
  ignore (arg_kinds img refs row);
  if sg.ret <> S.Void then ignore (sig_kind img refs "a result not an int32" sg.ret);
  let body = Image.body img (Image.get img t row "RVA") in
  if body.clauses <> [] && not refs then refuse "exception clauses: the interpreter's";
  List.iter (fun (c : Image.clause) ->
      if c.kind = 1 then refuse "an exception filter: the interpreter's";
      if c.kind = 4 then refuse "a fault clause: the interpreter's") body.clauses;
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
  | Il.Castclass _ | Il.Isinst _ | Il.Box _ | Il.Unbox_any _ | Il.Throw
  | Il.Ldloca _ | Il.Ldarga _ | Il.Ldftn _ | Il.Initobj _ | Il.Ldflda _ | Il.Ldsflda _ | Il.Ldelema _
  | Il.Ldelem_any _ | Il.Stelem_any _ | Il.Constrained _ | Il.Ldobj _ | Il.Stobj _
  | Il.Leave _ | Il.Endfinally | Il.Rethrow | Il.Ldtoken _ -> refs
  | Il.Ldelem k | Il.Stelem k | Il.Ldind k | Il.Stind k -> refs && (int_kind k || k = Il.K_ref)
  | _ -> false

(* a field, in the loaded assembly *)
let field (im : Value.image) (tok : int) : Value.field =
  let targs, margs = match !instance with Some i -> i | None -> ([||], [||]) in
  Types.field_of_token { im; targs; margs } tok

(* the most operands of a call-out: on arm, mini-ml's registers of
 * arguments are R1 to R8, the call-out's number in R1 *)
let outs = 7

(* a call-out's operands and whether it pushes a value; None, done by
 * the code itself *)
let call_out (img : Image.t) (im : Value.image option) (taken : int -> bool) (caller : int) (st : V.vt list)
    (op : Il.op) : (int * bool) option =
  (* (a field the code reads and writes itself: an object's, an int32 or
   * a reference; a struct's through an address, or a struct, is the
   * interpreter's) *)
  let by_code tok obj =
    (match obj with V.Obj _ -> true | _ -> false)
    && (match im with
        | Some im -> (match (field im tok).ftype with Value.T_value _ -> false | _ -> true)
        | None -> true) in
  match op with
  | Il.Call tok | Il.Callvirt tok ->
      let m, _ = V.call_sig img tok in
      let callee = M.token_row tok in
      (* a direct call: a static method compiled, whose class is the
       * caller's or has no static constructor to run first *)
      if (match op with Il.Call _ -> true | _ -> false) && M.token_table tok = M.t_method_def
         && not m.has_this && taken callee
         && not (List.exists (fun p -> match p with S.ByRef _ -> true | _ -> false) m.params)
         && (owner img callee = owner img caller || not (has_cctor img (owner img callee)))
      then None
      else Some (List.length m.params + (if m.has_this then 1 else 0), m.ret <> S.Void)
  | Il.Newobj tok -> let m, _ = V.call_sig img tok in Some (List.length m.params, true)
  | Il.Ldstr _ | Il.Ldsfld _ -> Some (0, true)
  | Il.Newarr _ | Il.Castclass _ | Il.Isinst _ | Il.Box _ | Il.Unbox_any _ -> Some (1, true)
  | Il.Stsfld _ | Il.Throw -> Some (1, false)
  | Il.Stelem Il.K_ref -> Some (3, false)
  | Il.Ldind _ | Il.Ldobj _ -> Some (1, true)
  | Il.Stobj _ -> Some (2, false)
  (* (a field's or an element's address: the interpreter's Ptr, opaque
   * to the code, given to call-outs) *)
  | Il.Ldsflda _ -> Some (0, true)
  | Il.Ldflda _ -> Some (1, true)
  | Il.Ldelema _ | Il.Ldelem_any _ -> Some (2, true)
  | Il.Stelem_any _ -> Some (3, false)
  | Il.Stind _ -> Some (2, false)
  | Il.Initobj _ -> Some (1, false)
  | Il.Stfld tok when (match im with Some im -> Value.is_ref (field im tok).ftype | None -> false) -> Some (2, false)
  | Il.Stfld tok when not (by_code tok (match st with _ :: o :: _ -> o | _ -> V.Obj None)) -> Some (2, false)
  | Il.Ldfld tok when not (by_code tok (match st with o :: _ -> o | _ -> V.Obj None)) -> Some (1, true)
  | Il.Ldtoken _ -> Some (0, true)
  | _ -> None

(* the operands of an instruction the code does itself (not a
 * call-out): Ret's, the stack's depth *)
let pops (img : Image.t) (op : Il.op) (depth : int) : int =
  match op with
  | Il.Starg _ | Il.Stloc _ | Il.Pop | Il.Brfalse _ | Il.Brtrue _ | Il.Switch _ | Il.Neg | Il.Not
  | Il.Conv _ | Il.Ldlen | Il.Ldfld _ | Il.Dup -> 1
  | Il.Binop _ | Il.Bcmp _ | Il.Ceq | Il.Cgt _ | Il.Clt _ | Il.Ldelem _ | Il.Stfld _ -> 2
  | Il.Stelem _ -> 3
  | Il.Ret | Il.Leave _ -> depth
  | Il.Call tok -> let m, _ = V.call_sig img tok in List.length m.params
  | _ -> 0

(* The addresses of locals and arguments (ldloca, ldarga: an int's
 * x.ToString(), out x, ref x): nothing at run time, the local is the
 * code's, not the interpreter's; followed from where it is pushed to
 * the call-out that takes it, which is given the local's value, and
 * gives back its new one (Jit_run: an interpreter's cell meanwhile).
 * At each call-out, its operands that are such addresses, by
 * (instruction, slot). An address taken by the code itself, or on the
 * stack at a jump's target, refuses the method. *)
let addresses (img : Image.t) (im : Value.image option) (row : int) (r : V.result) : (int * int, place) Hashtbl.t =
  let t = Hashtbl.create 4 and cur = Hashtbl.create 4 in
  let targets = Hashtbl.create 8 in
  Array.iter (fun (ins : Il.instr) -> match ins.op with
      | Il.Br x | Il.Brfalse x | Il.Brtrue x | Il.Bcmp (_, _, x) | Il.Leave x -> Hashtbl.replace targets x ()
      | Il.Switch xs -> Array.iter (fun x -> Hashtbl.replace targets x ()) xs
      | _ -> ()) r.instrs;
  Array.iter (fun (_, _, _, h, _) -> Hashtbl.replace targets h ()) (clauses img row r);
  Array.iteri (fun i (ins : Il.instr) ->
      match r.stacks.(i) with
      | None -> ()
      | Some st ->
          let d = List.length st in
          if Hashtbl.mem targets i then begin
            if Hashtbl.length cur > 0 then refuse (sprintf "IL_%04x: an address on the stack at a jump" ins.at);
            Hashtbl.reset cur
          end;
          match ins.op with
          | Il.Ldloca l -> Hashtbl.replace cur d (Local l)
          | Il.Ldarga a -> Hashtbl.replace cur d (Arg a)
          | Il.Ldftn _ -> Hashtbl.replace cur d (Ftn i)
          | Il.Dup -> (match Hashtbl.find_opt cur (d - 1) with Some p -> Hashtbl.replace cur d p | None -> ())
          | op ->
              let n = match call_out img im (fun _ -> false) row st op with
                | Some (n, _) ->
                    for k = d - n to d - 1 do
                      match Hashtbl.find_opt cur k with Some p -> Hashtbl.replace t (i, k) p | None -> ()
                    done;
                    n
                | None ->
                    let n = pops img op d in
                    for k = d - n to d - 1 do
                      if Hashtbl.mem cur k then refuse (sprintf "IL_%04x: an address to %s" ins.at ins.name)
                    done;
                    n in
              for k = d - n to d + 16 do Hashtbl.remove cur k done) r.instrs;
  t

(* the words a method has on mini-ml's value stack: its slots', its
 * locals', its arguments', when one may be a reference; else none *)
let value_words (img : Image.t) (row : int) (r : V.result) : int =
  let body = Image.body img (Image.get img M.t_method_def row "RVA") in
  let locals = List.map (sig_kind img true "") (local_sigs img body) in
  let args = Array.to_list (arg_kinds img true row) in
  let depth = Array.fold_left (fun d s -> match s with Some s -> max d (List.length s) | None -> d) 0 r.stacks in
  (* (and one a clause: its exception, while its handler runs) *)
  let nclauses = Array.length (clauses img row r) in
  let any_ref = List.mem R locals || List.mem R args || nclauses > 0
                || Array.exists (fun s -> match s with
                    | Some s -> List.exists (fun v -> vt_kind true v = Some R) s | None -> false) r.stacks in
  if any_ref then depth + 1 + List.length locals + List.length args + nclauses else 0

(* the methods the JIT takes: each one's own reasons, its stacks (the
 * verifier's: int32s only, or references), its instructions, and its
 * calls, to methods taken too (until no more is dropped); with
 * references, a call to another method is the interpreter's *)
(* a method the JIT takes, its stacks verified (V.Bad), or Refused
 * why; for an instance of a generic one, with !instance set *)
let accept (img : Image.t) (im : Value.image option) (row : int) : V.result =
  let refs = im <> None in
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
          (match call_out img im (fun _ -> false) row stack ins.op with
           | Some (n, _) when n > outs -> refuse (sprintf "IL_%04x: a call of %d arguments" ins.at n)
           | _ -> ())
      | (Il.Bcmp ((Il.Eq | Il.Ne), _, _) | Il.Ceq | Il.Cgt true), b :: a :: _ when is_ref a || is_ref b -> ()
      | (Il.Bcmp _ | Il.Cgt _ | Il.Clt _), b :: a :: _ when is_ref a || is_ref b ->
          refuse (sprintf "IL_%04x: %s of references" ins.at ins.name)
      | (Il.Ldfld tok | Il.Stfld tok), _ ->
          (match im with
           | Some im when (field im tok).fstatic -> refuse (sprintf "IL_%04x: a static field by %s" ins.at ins.name)
           | _ -> ())
      | _ -> ()) r.instrs;
  (* (a try's first instruction pushes its handler: a jump to it from
   * inside the try would push it twice) *)
  Array.iter (fun (_, ts, te, _, _) ->
      Array.iteri (fun i (ins : Il.instr) ->
          let to_start t = t = ts && i >= ts && i < te in
          match ins.op with
          | Il.Br t | Il.Brfalse t | Il.Brtrue t | Il.Bcmp (_, _, t) | Il.Leave t when to_start t ->
              refuse (sprintf "IL_%04x: a jump to its try's start" ins.at)
          | Il.Switch ts' when Array.exists to_start ts' -> refuse (sprintf "IL_%04x: a jump to its try's start" ins.at)
          | _ -> ()) r.instrs) (clauses img row r);
  if refs && value_words img row r > 32 then refuse "more than 32 words on the value stack";
  if refs then ignore (addresses img im row r);
  r

let choose (img : Image.t) (im : Value.image option) : (int, V.result) Hashtbl.t * (int * string) list =
  let refs = im <> None in
  let taken = Hashtbl.create 16 and refused = ref [] in
  for row = 1 to img.rows.(M.t_method_def) do
    match
      accept img im row
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
 * field, a cast, a reference stored (its write barrier). On arm the
 * same, a word of 4 bytes, the value stack's top R10. *)

(* what the code with references is made with: the assembly loaded,
 * the methods taken, the call-outs (numbered from base), a method's
 * cell (its address: the code's, its stub's until it is compiled) *)
type env = {
  im : Value.image;
  taken : int -> bool;
  sites : site list ref;
  base : int;
  cell : int -> string;
  limit : int;
  handler : int;               (* ml_handler's address: the records' chain *)
}

(* the text with references is written as arm64's; arm's the same but
 * for the names below (never in arm's templates of int32s, so their
 * text is the same as before) and the word's size, given apart: MOV a
 * word, MOVW on arm; the value stack's top, R26 or R10 (Gen's vsp);
 * the stack pointer; the scratch register of a call through a cell or
 * a closure (R16, arm64's IP0; R9 on arm, as mini-ml's own calls: the
 * operands of a call-out are in R2 to R8) *)
let replace_all (s : string) (a : string) (b : string) : string =
  let n = String.length a in
  let buf = Buffer.create (String.length s) in
  let rec go i =
    if i > String.length s - n then Buffer.add_string buf (String.sub s i (String.length s - i))
    else if String.sub s i n = a then (Buffer.add_string buf b; go (i + n))
    else (Buffer.add_char buf s.[i]; go (i + 1)) in
  go 0;
  Buffer.contents buf

let to_arm (s : string) : string =
  List.fold_left (fun s (a, b) -> replace_all s a b) s
    [ ("MOV\t", "MOVW\t"); ("LSL\t", "SLL\t"); ("ASR\t", "SRA\t");
      ("R26", "R10"); ("R31", "R13"); ("R16", "R9"); ("RETURN", "RET");
      ("RSP", "R13"); ("LSR\t", "SRL\t") ]

let method_text (m : mach) (img : Image.t) (syms : (int, string) Hashtbl.t) (row : int) (r : V.result)
    (refs : env option) : string =
  let b = Buffer.create 1024 in
  let a64 = m = Arm64 in
  let ins fmt = Printf.ksprintf (fun s -> Buffer.add_string b ("\t" ^ (if a64 then s else to_arm s) ^ "\n")) fmt in
  let w = if a64 then 8 else 4 in
  let store_s = w and store_r = 2 * w and store_len = 3 * w in
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
  let taken = match refs with Some e -> e.taken | None -> (fun _ -> true) in
  let im = match refs with Some e -> Some e.im | None -> None in
  (* the outgoing arguments' room: the most a call passes, 5c's way *)
  let maxargs = Array.fold_left (fun a (ins : Il.instr) -> match ins.op with
      | Il.Call tok when refs = None || call_out img im taken row [] ins.op = None ->
          let m, _ = V.call_sig img tok in
          max a (List.length m.params)
      | _ -> a) 1 r.instrs in
  (* a try's clause: its handler's record (4 words: Gen's ml_try's) and
   * a finally's continuation, in the frame; its exception, a value *)
  let cls = if refs <> None then clauses img row r else [||] in
  let ncl = Array.length cls in
  let frame = w * (nslots + nlocals + 5 * ncl) + w * maxargs in
  (* the value stack's words: the slots, the locals, the arguments *)
  let nv = if refs <> None then value_words img row r else 0 in
  let word j = sprintf "%d(R26)" (-w * (nv - j)) in
  (* the places: a stack slot, a local (autos, below SP), an argument
   * (FP: the first one left there from R0 by the prologue's MOVW) *)
  let slot k = sprintf "s%d-%d(SP)" k (w * (k + 1)) in
  let local i = sprintf "l%d-%d(SP)" i (w * (nslots + i + 1)) in
  let arg i = sprintf "a%d+%d(FP)" i (w * i) in
  let vslot k = word k and vlocal i = word (nslots + i) and varg i = word (nslots + nlocals + i) in
  let record c j = sprintf "r%d_%d-%d(SP)" c j (w * (nslots + nlocals + (5 * c) + 4 - j)) in
  let cont c = sprintf "k%d-%d(SP)" c (w * (nslots + nlocals + (5 * c) + 5)) in
  let vexn c = word (nslots + nlocals + nargs + c) in
  let label i = sprintf "%s_%d" sym i in
  let addrs = if refs <> None then addresses img im row r else Hashtbl.create 1 in
  let targets = Hashtbl.create 8 in
  Array.iter (fun (ins : Il.instr) -> match ins.op with
      | Il.Br t | Il.Brfalse t | Il.Brtrue t | Il.Bcmp (_, _, t) | Il.Leave t -> Hashtbl.replace targets t ()
      | Il.Switch ts -> Array.iter (fun t -> Hashtbl.replace targets t ()) ts
      | _ -> ()) r.instrs;
  Array.iter (fun (_, _, _, h, _) -> Hashtbl.replace targets h ()) cls;
  (* a call-out of a try's: its number in R1, an operand in R2 *)
  let try_site op nargs ret =
    match refs with
    | Some e ->
        let number = e.base + List.length !(e.sites) in
        e.sites := !(e.sites) @ [ { srow = row; sat = 0; sargs = List.init nargs (fun _ -> R);
                                     sform = List.init nargs (fun _ -> Word); sret = ret; sop = op } ];
        number
    | None -> assert false in
  let handler = match refs with Some e -> e.handler | None -> 0 in
  (* a finally's continuations: the places a leave goes on from, by the
   * number in its continuation word *)
  let resumes = Array.make ncl [] in
  (* the structs: a local's, an argument's, copied when loaded *)
  let is_struct t = match V.of_sig img t with Some (V.Value _) -> true | _ -> false in
  let struct_local = Array.of_list (List.map is_struct (local_sigs img body)) in
  let struct_arg = Array.of_list ((if sg.has_this then [ false ] else []) @ List.map is_struct sg.params) in
  let copy k =
    ins "MOV\t%s, R2" (vslot k);
    ins "MOV\t$%d, R1" (2 * try_site Copy 1 (Some R) + 1);
    ins "BL\tjit_out1(SB)";
    ins "MOV\tR0, %s" (vslot k) in
  Buffer.add_string b (sprintf "// %s, %d bytes of IL: %d slots, %d locals\n"
                         (Listing.token_name img (M.token M.t_method_def row)) (String.length body.code) nslots nlocals);
  Buffer.add_string b (sprintf "\tTEXT\t%s(SB), 0, $%d\n" sym frame);
  if nargs > 0 && args.(0) = I then ins "MOVW\tR0, %s" (arg 0);
  (* the machine's stack checked: a recursion with no end is the
   * interpreter's Stack_overflow (jit_overflow), as its 10,000 frames,
   * not a fault; the limit in words (an address past an int's 31 bits
   * on arm) *)
  (match refs with
   | Some e when e.limit > 0 ->
       ins "MOV\t$%d, R1" e.limit;
       ins "MOV\tRSP, R2";
       ins "LSR\t$2, R2";
       ins "CMP\tR1, R2";
       ins "BHS\t2(PC)";
       ins "BL\tjit_overflow(SB)"
   | _ -> ());
  if nv > 0 then begin
    (* the words above the caller's: each a value (1, null) before the
     * collector can see them; the references given, copied there *)
    ins "ADD\t$%d, R26" (w * nv);
    ins "MOV\t$1, R1";
    for j = 0 to nv - 1 do ins "MOV\tR1, %s" (word j) done;
    Array.iteri (fun i k ->
        if k = R then
          if i = 0 then ins "MOV\tR0, %s" (varg 0)
          else (ins "MOV\t%s, R1" (arg i); ins "MOV\tR1, %s" (varg i))) args
  end;
  (* a struct local its zeros, the interpreter's *)
  Array.iteri (fun l st ->
      if st then begin
        ins "MOV\t$%d, R1" (2 * try_site (Init l) 0 (Some R) + 1);
        ins "BL\tjit_out0(SB)";
        ins "MOV\tR0, %s" (vlocal l)
      end) struct_local;
  (* the locals zeroed, as .locals init asks (C#'s always does) *)
  if Array.exists (( = ) I) locals then begin
    ins "MOVW\t$0, R1";
    Array.iteri (fun i k -> if k = I then ins "MOVW\tR1, %s" (local i)) locals
  end;
  let return () =
    if nv > 0 then ins "SUB\t$%d, R26" (w * nv);
    ins "%s" (if a64 then "RETURN" else "RET") in
  Array.iteri (fun i (x : Il.instr) ->
      if Hashtbl.mem targets i then Buffer.add_string b (label i ^ ":\n");
      (* a try entered (the outer first): its frame for the first pass,
       * its record pushed (jit_try returns 0; a raise comes back there
       * with the exception, to its handler) *)
      for c = ncl - 1 downto 0 do
        let _, ts, _, _, _ = cls.(c) in
        if ts = i then begin
          Buffer.add_string b (sprintf "\t// a try, clause %d\n" c);
          ins "MOV\t$%d, R1" (2 * try_site (Enter c) 0 None + 1);
          ins "BL\tjit_out0(SB)";
          ins "MOV\t$%s, R0" (record c 0);
          ins "BL\tjit_try(SB)";
          ins "CMP\t$0, R0";
          ins "BNE\t%s_h%d" sym c
        end
      done;
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
      (* R0 an int32 from ML: tagged; on arm, tagged or boxed (an Int32's
       * block, its bits at 0) *)
      let unbox_reg r =
        if a64 then ins "ASR\t$1, %s" r
        else (ins "TST\t$1, %s" r; ins "MOVW.EQ\t0(%s), %s" r r; ins "SRA.NE\t$1, %s" r) in
      let unbox () = unbox_reg "R0" in
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
      | Some { sites; base; _ }, _ when call_out img im taken row (match r.stacks.(i) with Some s -> s | None -> []) x.op <> None ->
          (* the instruction run by the interpreter: its operands, the
           * bottom first, as values of mini-ml's (an int32 tagged), in
           * R2...; the call-out's number in R1 *)
          let n, pushes = match call_out img im taken row (match r.stacks.(i) with Some s -> s | None -> []) x.op with
            | Some p -> p | None -> assert false in
          (* (an operand that is a local's address: the local's value, of
           * its kind, from its place; its new value given back) *)
          let place j = Hashtbl.find_opt addrs (i, top - n + 1 + j) in
          let home j = match place j with
            | Some (Local l) -> (locals.(l), local l, vlocal l)
            | Some (Arg a) -> (args.(a), arg a, varg a)
            | Some (Ftn _) -> (R, "", "$1")
            | None -> let s = top - n + 1 + j in (before s, slot s, vslot s) in
          let kinds = List.init n (fun j -> let k, _, _ = home j in k) in
          let ret = if pushes then Some (after (top - n + 1)) else None in
          let number = base + List.length !sites in
          let sform = List.init n (fun j -> match place j with
              | Some (Local _ | Arg _) -> Addr | Some (Ftn k) -> Made k | None -> Word) in
          sites := !sites @ [ { srow = row; sat = i; sargs = kinds; sform; sret = ret; sop = Run } ];
          (* (on arm an int32 past 31 bits boxed first, jit_box, its block
           * in the slot's word of the value stack, where it waits) *)
          if not a64 then
            List.iteri (fun j k ->
                let s = top - n + 1 + j in
                let _, src, _ = home j in
                if k = I then begin
                  ins "MOVW\t%s, R1" src;
                  ins "ADD.S\tR1, R1, R2";
                  ins "BVC\t3(PC)";
                  ins "BL\tjit_box(SB)";
                  ins "MOVW\tR0, %s" (vslot s)
                end) kinds;
          ins "MOV\t$%d, R1" (2 * number + 1);
          List.iteri (fun j k ->
              let s = top - n + 1 + j in
              let _, src, vsrc = home j in
              if k = R then ins "MOV\t%s, R%d" vsrc (j + 2)
              else if a64 then (ins "MOVW\t%s, R%d" src (j + 2); ins "LSL\t$1, R%d" (j + 2); ins "ORR\t$1, R%d" (j + 2))
              else begin
                ins "MOVW\t%s, R%d" src (j + 2);
                ins "ADD.S\tR%d, R%d, R%d" (j + 2) (j + 2) (j + 2);
                ins "ORR.VC\t$1, R%d" (j + 2);
                ins "MOVW.VS\t%s, R%d" (vslot s) (j + 2)
              end) kinds;
          ins "BL\tjit_out%d(SB)" n;
          (* the locals' new values, then the result: an array of them *)
          if List.mem Addr sform then begin
            let m = ref 0 in
            List.iteri (fun j k ->
                if List.nth sform j = Addr then begin
                  incr m;
                  let _, src, vsrc = home j in
                  ins "MOV\t%d(R0), R1" (w * !m);
                  if k = I then (unbox_reg "R1"; ins "MOVW\tR1, %s" src) else ins "MOV\tR1, %s" vsrc
                end) kinds;
            ins "MOV\t0(R0), R0"
          end;
          (match ret with
           | Some I -> unbox (); ins "MOVW\tR0, %s" (slot (top - n + 1))
           | Some R -> ins "MOV\tR0, %s" (vslot (top - n + 1))
           | None -> ())
      | _, Il.Nop | _, Il.Prefix _ | _, Il.Constrained _ | _, Il.Ldloca _ | _, Il.Ldarga _ | _, Il.Ldftn _ -> ()
      | _, Il.Ldarg a -> move args.(a) (arg a, varg a) (slot (top + 1), vslot (top + 1));
          if refs <> None && struct_arg.(a) then copy (top + 1)
      | _, Il.Starg a -> move args.(a) (slot top, vslot top) (arg a, varg a)
      | _, Il.Ldloc l -> move locals.(l) (local l, vlocal l) (slot (top + 1), vslot (top + 1));
          if refs <> None && struct_local.(l) then copy (top + 1)
      | _, Il.Stloc l -> move locals.(l) (slot top, vslot top) (local l, vlocal l)
      | _, Il.Ldc_i4 n -> ins "MOVW\t$%ld, R1" n; ins "MOVW\tR1, %s" (slot (top + 1))
      | _, Il.Ldnull -> ins "MOV\t$1, R1"; ins "MOV\tR1, %s" (vslot (top + 1))
      | _, Il.Dup -> move (before top) (slot top, vslot top) (slot (top + 1), vslot (top + 1));
          if refs <> None && (match r.stacks.(i) with Some (V.Value _ :: _) -> true | _ -> false) then copy (top + 1)
      | _, Il.Pop -> ()
      | Some { im; _ }, (Il.Ldfld tok | Il.Stfld tok) ->
          let fd = field im tok in
          let is_ref = Value.is_ref fd.ftype in
          (match x.op with
           | Il.Ldfld _ ->
               store_of top;
               if is_ref then (ins "MOV\t%d(R1), R1" store_r; ins "MOV\t%d(R1), R1" (w * fd.roff); ins "MOV\tR1, %s" (vslot top))
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
          element top w true;
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
      | Some _, Il.Binop ((Il.Div | Il.Div_un | Il.Rem | Il.Rem_un) as o) when not a64 ->
          (* arm's (the Pi 1's ARMv6) has no division: the runtime's
           * unsigned one (jit_udiv), the signs here *)
          pair (fun () ->
              ins "CMP\t$0, R2";
              ins "BNE\t2(PC)";
              ins "BL\tjit_divide_by_zero(SB)";
              let signed = o = Il.Div || o = Il.Rem in
              if signed then begin
                ins "MOVW\tR1, R5";
                ins "EOR\tR1, R2, R6";
                ins "CMP\t$0, R1";
                ins "RSB.LT\t$0, R1, R1";
                ins "CMP\t$0, R2";
                ins "RSB.LT\t$0, R2, R2"
              end;
              ins "BL\tjit_udiv(SB)";
              match o with
              | Il.Div -> ins "CMP\t$0, R6"; ins "RSB.LT\t$0, R1, R1"
              | Il.Rem -> ins "MOVW\tR2, R1"; ins "CMP\t$0, R5"; ins "RSB.LT\t$0, R1, R1"
              | Il.Rem_un -> ins "MOVW\tR2, R1"
              | _ -> ())
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
          (match refs with
           | Some e -> ins "MOV\t%s, R16" (e.cell callee); ins "MOV\t0(R16), R16"; ins "BL\t(R16)"
           | None -> ins "BL\t%s(SB)" (Hashtbl.find syms callee));
          let sg' = signature img callee in
          if sg'.ret <> S.Void then
            if sig_kind img (refs <> None) "" sg'.ret = I then ins "MOVW\tR0, %s" (slot (top - n + 1))
            else ins "MOV\tR0, %s" (vslot (top - n + 1))
      | _, Il.Leave t ->
          (* the trys it leaves, the inner first: each record popped (its
           * previous one the chain's again), its frame; a finally run,
           * which comes back here *)
          Array.iteri (fun c (kind, ts, te, hs, _) ->
              if i >= ts && i < te && not (t >= ts && t < te) then begin
                ins "MOV\t%s, R1" (record c 3);
                ins "MOV\t$%d, R16" handler;
                ins "MOV\tR1, 0(R16)";
                ins "MOV\t$%d, R1" (2 * try_site Leave_try 0 None + 1);
                ins "BL\tjit_out0(SB)";
                if kind = 2 then begin
                  let k = List.length resumes.(c) in
                  let back = sprintf "%s_%d_f%d" sym i c in
                  resumes.(c) <- resumes.(c) @ [ (k, back) ];
                  ins "MOVW\t$%d, R1" k;
                  ins "MOVW\tR1, %s" (cont c);
                  ins "B\t%s" (label hs);
                  Buffer.add_string b (back ^ ":\n")
                end
              end) cls;
          ins "B\t%s" (label t)
      | _, Il.Endfinally ->
          (* where its continuation says, or the exception again *)
          Array.iteri (fun c (kind, _, _, hs, he) ->
              if kind = 2 && i >= hs && i < he then begin
                ins "MOVW\t%s, R1" (cont c);
                ins "CMP\t$-1, R1";
                ins "BNE\t%s_e%d_%d" sym i c;
                ins "MOV\t%s, R2" (vexn c);
                ins "MOV\t$%d, R1" (2 * try_site Reraise 1 None + 1);
                ins "BL\tjit_out1(SB)";
                Buffer.add_string b (sprintf "%s_e%d_%d:\n" sym i c);
                List.iter (fun (k, back) -> ins "CMP\t$%d, R1" k; ins "BEQ\t%s" back) resumes.(c)
              end) cls
      | _, Il.Rethrow ->
          Array.iteri (fun c (kind, _, _, hs, he) ->
              if kind = 0 && i >= hs && i < he then begin
                ins "MOV\t%s, R2" (vexn c);
                ins "MOV\t$%d, R1" (2 * try_site Rethrow 1 None + 1);
                ins "BL\tjit_out1(SB)"
              end) cls
      | _, Il.Ret ->
          if sg.ret <> S.Void then
            if before top = I then ins "MOVW\t%s, R0" (slot top) else ins "MOV\t%s, R0" (vslot top);
          return ()
      | _ -> assert false) r.instrs;
  (* the handlers: the exception (R0) given to the interpreter's rule
   * (Machine.run's): a catch's caught, else raised again; a finally's
   * kept (a .NET exception's) and the finally run *)
  Array.iteri (fun c (kind, _, _, hs, _) ->
      Buffer.add_string b (sprintf "%s_h%d:\n" sym c);
      ins "MOV\tR0, R2";
      ins "MOV\t$%d, R1" (2 * try_site (Catch c) 1 (Some R) + 1);
      ins "BL\tjit_out1(SB)";
      ins "MOV\tR0, %s" (vexn c);
      if kind = 0 then ins "MOV\tR0, %s" (vslot 0)
      else (ins "MOVW\t$-1, R1"; ins "MOVW\tR1, %s" (cont c));
      ins "B\t%s" (label hs)) cls;
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

(* each method's text, its call-outs numbered from 0, a method's cell
 * by its symbol: -S's *)
let assembly (m : mach) (img : Image.t) (im : Value.image option) : string * int * (int * string) list =
  let taken, refused = choose img im in
  let rows, syms = symbols img taken in
  let sites = ref [] in
  let b = Buffer.create 4096 in
  List.iter (fun row ->
      let refs = match im with
        | Some im -> Some { im; taken = Hashtbl.mem taken; sites; base = 0;
                            cell = (fun r -> sprintf "$%s_cell(SB)" (Hashtbl.find syms r)); limit = 0; handler = 0 }
        | None -> None in
      Buffer.add_string b (method_text m img syms row (Hashtbl.find taken row) refs)) rows;
  (Buffer.contents b, List.length rows, refused)

(* ------------------------------------------------------------------ *)
(* In mini-dotnet: a method compiled at its first call *)
(* ------------------------------------------------------------------ *)

type prepared = {
  prefused : (int * string) list;
  pmach : mach;
  pim : Value.image;
  ptaken : (int, V.result) Hashtbl.t;
  prows : int list;
  psyms : (int, string) Hashtbl.t;
}

let prepare (m : mach) (im : Value.image) : prepared =
  let taken, refused = choose im.img (Some im) in
  let rows, syms = symbols im.img taken in
  { prefused = refused; pmach = m; pim = im; ptaken = taken; prows = rows; psyms = syms }

let rows (p : prepared) : int list = p.prows
let refused (p : prepared) : (int * string) list = p.prefused

(* the runtime's, in each piece of code (its own copy, the pieces apart
 * in memory): an ML function's static closure at an address, called
 * by its n-ary code (field 1) with the code's link kept: a throw's, of
 * unit, which raises and so does not come back; a call-out's, of its
 * number in R1 and its operands; the compiler's, of a method's number.
 * On arm, the box of an int32 past 31 bits (in R1: its halves given,
 * tagged, to [box]) and the unsigned division (R1 / R2: the quotient
 * in R1, the remainder in R2; libc's div.s's binary search for the
 * first bit, then a bit a turn) *)
let runtime ~(mach : mach) ~(throws : (string * int) list) ~(out : int array) ~(compile : int) ~(box : int)
    ~(handler : int) : string =
  let a64 = mach = Arm64 in
  let w = if a64 then 8 else 4 in
  let b = Buffer.create 1024 in
  let add t = Buffer.add_string b (if a64 then t else to_arm t) in
  let frame = if a64 then "$-8" else "$-4" in
  let call addr = sprintf "\tMOV\t$%d, R0\n\tMOV\t%d(R0), R16\n\tB\t(R16)\n" addr w in
  List.iter (fun (name, addr) -> add (sprintf "\tTEXT\t%s(SB), %s\n\tMOV\t$1, R1\n%s" name frame (call addr))) throws;
  Array.iteri (fun n addr -> add (sprintf "\tTEXT\tjit_out%d(SB), %s\n%s" n frame (call addr))) out;
  add (sprintf "\tTEXT\tjit_compile(SB), %s\n%s" frame (call compile));
  (* a try's record pushed on ML's chain of handlers, at R0 (Gen's
   * ml_try: the stack pointer, the value stack's top, the return
   * address, the previous record), 0 returned; a raise returns there
   * again, the exception in R0 *)
  Buffer.add_string b
    (if a64 then sprintf "\tTEXT\tjit_try(SB), $-8\n\tMOV\tRSP, R16\n\tMOV\tR16, 0(R0)\n\tMOV\tR26, 8(R0)\n\tMOV\tR30, 16(R0)\n\tMOV\t$%d, R16\n\tMOV\t0(R16), R17\n\tMOV\tR17, 24(R0)\n\tMOV\tR0, 0(R16)\n\tMOV\t$0, R0\n\tRET\t(R30)\n" handler
     else sprintf "\tTEXT\tjit_try(SB), $-4\n\tMOVW\tR13, 0(R0)\n\tMOVW\tR10, 4(R0)\n\tMOVW\tR14, 8(R0)\n\tMOVW\t$%d, R9\n\tMOVW\t0(R9), R4\n\tMOVW\tR4, 12(R0)\n\tMOVW\tR0, 0(R9)\n\tMOVW\t$0, R0\n\tRET\n" handler);
  if not a64 then begin
    add (sprintf "\tTEXT\tjit_box(SB), $-4\n\tMOVW\tR1, R2\n\tSLL\t$16, R2\n\tSRL\t$15, R2\n\tORR\t$1, R2\n\tSRA\t$16, R1\n\tSLL\t$1, R1\n\tORR\t$1, R1\n%s" (call box));
    add "\tTEXT\tjit_udiv(SB), $-4\n\tMOVW\t$0, R4\n\tMOVW\t$0, R3\n";
    List.iter (fun k ->
        add (sprintf "\tCMP\tR1>>%d, R2\n\tBHI\tjit_udiv_%d\n\tSLL\t$%d, R2\n\tADD\t$%d, R3\njit_udiv_%d:\n" k k k k k))
      [ 16; 8; 4; 2; 1 ];
    add "jit_udiv_turn:\n\tCMP\tR2, R1\n\tSUB.HS\tR2, R1\n\tADC\tR4, R4\n\tSRL\t$1, R2\n\tSUB.S\t$1, R3\n\tBGE\tjit_udiv_turn\n\tMOVW\tR1, R2\n\tMOVW\tR4, R1\n\tRET\n"
  end;
  Buffer.contents b

(* An entry, as mini-ml calls a closure of one argument (Gen: the
 * closure in R0, its argument in R1, the result in R0): the argument
 * an array of the method's arguments, values of mini-ml's (an int32 a
 * tagged int; on arm, boxed past 31 bits); each put in 7c's or 5c's
 * places, an int32 untagged, the method called by its cell, its
 * result tagged (2n + 1) or boxed (jit_box), a reference as it is. The
 * value stack's top (R26, R10) is the caller's, which the method
 * raises if it holds references. *)
let entry (m : mach) (img : Image.t) (sym : string) (row : int) (cell : int option) : string =
  let b = Buffer.create 256 in
  let a64 = m = Arm64 in
  let w = if a64 then 8 else 4 in
  let ins fmt = Printf.ksprintf (fun s -> Buffer.add_string b ("\t" ^ (if a64 then s else to_arm s) ^ "\n")) fmt in
  let untag r =
    if a64 then ins "ASR\t$1, %s" r
    else (ins "TST\t$1, %s" r; ins "MOVW.EQ\t0(%s), %s" r r; ins "SRA.NE\t$1, %s" r) in
  let sg = signature img row in
  let ks = arg_kinds img true row in
  let n = Array.length ks in
  Buffer.add_string b (sprintf "\tTEXT\t%s_entry(SB), 0, $%d\n" sym (w * (n + 1)));
  for k = n - 1 downto 1 do
    ins "MOV\t%d(R1), R2" (w * k);
    if ks.(k) = I then (untag "R2"; ins "MOVW\tR2, %d(R31)" (w + w * k))
    else ins "MOV\tR2, %d(R31)" (w + w * k)
  done;
  if n > 0 then (ins "MOV\t0(R1), R0"; if ks.(0) = I then untag "R0");
  (match cell with
   | Some c -> ins "MOV\t$%d, R16" c; ins "MOV\t0(R16), R16"; ins "BL\t(R16)"
   | None -> ins "BL\t%s(SB)" sym);
  if sg.ret = S.Void then ins "MOV\t$1, R0"
  else if sig_kind img true "" sg.ret = I then begin
    if a64 then (ins "LSL\t$1, R0"; ins "ORR\t$1, R0")
    else begin
      ins "ADD.S\tR0, R0, R1";
      ins "ORR.VC\t$1, R1, R0";
      ins "BVC\t3(PC)";
      ins "MOVW\tR0, R1";
      ins "BL\tjit_box(SB)"
    end
  end;
  ins "RETURN";
  Buffer.contents b

(* A stub, a method's cell's until it is compiled: a function of the
 * method's arguments, which compiles it (jit_compile, its number in
 * R1: the compiler allocates, so the references given wait on the
 * value stack, where the collector moves them), then calls it with
 * them through its cell, and returns its result: decision 12's stub,
 * as .NET's first JIT had (its "prestub") *)
let stub (m : mach) (img : Image.t) (sym : string) (row : int) (cell : int) (number : int) : string =
  let b = Buffer.create 256 in
  let a64 = m = Arm64 in
  let w = if a64 then 8 else 4 in
  let ins fmt = Printf.ksprintf (fun s -> Buffer.add_string b ("\t" ^ (if a64 then s else to_arm s) ^ "\n")) fmt in
  let ks = arg_kinds img true row in
  let n = Array.length ks in
  let refs = List.filter (fun i -> ks.(i) = R) (List.init n (fun i -> i)) in
  let nr = List.length refs in
  let word i = let rec index j l = match l with x :: l -> if x = i then j else index (j + 1) l | [] -> 0 in
    sprintf "%d(R26)" (-w * (nr - index 0 refs)) in
  let arg i = sprintf "a%d+%d(FP)" i (w * i) in
  Buffer.add_string b (sprintf "\tTEXT\t%s_stub(SB), 0, $%d\n" sym (w * (n + 1)));
  if n > 0 && ks.(0) = I then ins "MOVW\tR0, %s" (arg 0);
  if nr > 0 then begin
    ins "ADD\t$%d, R26" (w * nr);
    List.iter (fun i -> if i = 0 then ins "MOV\tR0, %s" (word 0)
                else (ins "MOV\t%s, R1" (arg i); ins "MOV\tR1, %s" (word i))) refs
  end;
  ins "MOV\t$%d, R1" (2 * number + 1);
  ins "BL\tjit_compile(SB)";
  for i = n - 1 downto 1 do
    if ks.(i) = I then (ins "MOVW\t%s, R1" (arg i); ins "MOVW\tR1, %d(R31)" (w + w * i))
    else (ins "MOV\t%s, R1" (word i); ins "MOV\tR1, %d(R31)" (w + w * i))
  done;
  if n > 0 then (if ks.(0) = I then ins "MOVW\t%s, R0" (arg 0) else ins "MOV\t%s, R0" (word 0));
  if nr > 0 then ins "SUB\t$%d, R26" (w * nr);
  ins "MOV\t$%d, R16" cell;
  ins "MOV\t0(R16), R16";
  ins "BL\t(R16)";
  ins "RETURN";
  Buffer.contents b

let symbol_of (p : prepared) (row : int) : string = Hashtbl.find p.psyms row

(* the stack pointer, in words, tagged: a closure's code of one
 * argument, unit (the stack's limit is below it) *)
let sp_code (m : mach) : string =
  if m = Arm64 then "\tTEXT\tjit_sp(SB), $-8\n\tMOV\tRSP, R0\n\tLSR\t$2, R0\n\tLSL\t$1, R0\n\tORR\t$1, R0\n\tRET\t(R30)\n"
  else "\tTEXT\tjit_sp(SB), $-4\n\tMOVW\tR13, R0\n\tSRL\t$2, R0\n\tSLL\t$1, R0\n\tORR\t$1, R0\n\tRET\n"

let stubs (p : prepared) ~(cell : int -> int) ~(number : int -> int) ~(runtime : string) :
  string * (int * string) list * (int * string) list =
  let b = Buffer.create 4096 in
  List.iter (fun row ->
      let sym = symbol_of p row in
      Buffer.add_string b (entry p.pmach p.pim.img sym row (Some (cell row)));
      Buffer.add_string b (stub p.pmach p.pim.img sym row (cell row) (number row))) p.prows;
  Buffer.add_string b runtime;
  (Buffer.contents b,
   List.map (fun row -> (row, symbol_of p row ^ "_entry")) p.prows,
   List.map (fun row -> (row, symbol_of p row ^ "_stub")) p.prows)

let method_code (p : prepared) (row : int) ~(cell : int -> int) ~(base : int) ~(limit : int) ~(handler : int)
    ~(runtime : string) : string * site list =
  let sites = ref [] in
  let env = { im = p.pim; taken = Hashtbl.mem p.ptaken; sites; base; cell = (fun r -> sprintf "$%d" (cell r));
              limit; handler } in
  let text = method_text p.pmach p.pim.img p.psyms row (Hashtbl.find p.ptaken row) (Some env) in
  (text ^ runtime, !sites)

(* An instance of a generic method (of a generic class, or generic
 * itself), compiled at its first call: the method checked and its text
 * made with its type arguments (instance), an entry calling it by BL,
 * the runtime's; every call it makes a call-out. None if refused. *)
let instance_code (m : mach) (meth : Value.meth) ~(base : int) ~(limit : int) ~(handler : int) ~(runtime : string) :
  (string * string * site list) option =
  match meth.def with
  | None -> None
  | Some (im, row) ->
      instance := Some (meth.mcls.args, meth.margs);
      let made = try
        match accept im.img (Some im) row with
        | exception (Refused _ | V.Bad _ | Types.Load_error _) -> None
        | r ->
            let sym = symbol im.img row ^ "_inst" in
            let syms = Hashtbl.create 1 in
            Hashtbl.replace syms row sym;
            let sites = ref [] in
            let env = { im; taken = (fun _ -> false); sites; base; cell = (fun _ -> "$0"); limit; handler } in
            let text = method_text m im.img syms row r (Some env) in
            Some (text ^ entry m im.img sym row None ^ runtime, sym ^ "_entry", !sites)
        with e -> instance := None; raise e in
      instance := None;
      made
