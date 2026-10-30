(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Jit.mli *)

module M = Metadata
module S = Signature
module V = Verifier

exception Refused of string

let refuse (why : string) = raise (Refused why)
let sprintf = Printf.sprintf

(* ------------------------------------------------------------------ *)
(* Which methods: static, of int32s only, calling only such methods *)
(* ------------------------------------------------------------------ *)

let int32_sig (t : S.t) : bool =
  match t with
  | S.Bool | S.Char | S.I1 | S.U1 | S.I2 | S.U2 | S.I4 | S.U4 -> true
  | _ -> false

(* a method's own reasons: its signature, its locals, its clauses *)
let own (img : Image.t) (row : int) : unit =
  let t = M.t_method_def in
  if Image.get img t row "RVA" = 0 then refuse "no body";
  let sg = S.method_ (Image.blob img (Image.get img t row "Signature")) in
  if sg.has_this then refuse "an instance method: this is a reference";
  if sg.generic > 0 then refuse "a generic method";
  List.iter (fun p -> if not (int32_sig p) then refuse "a parameter not an int32") sg.params;
  if sg.ret <> S.Void && not (int32_sig sg.ret) then refuse "a result not an int32";
  let body = Image.body img (Image.get img t row "RVA") in
  if body.clauses <> [] then refuse "exception clauses: the interpreter's";
  if body.locals_token <> 0 then
    List.iter (fun l -> if not (int32_sig l) then refuse "a local not an int32")
      (S.locals (Image.blob img (Image.get img M.t_stand_alone_sig (M.token_row body.locals_token) "Signature")))

(* an instruction the templates have *)
let supported (op : Il.op) : bool =
  match op with
  | Il.Nop | Il.Ldarg _ | Il.Starg _ | Il.Ldloc _ | Il.Stloc _ | Il.Ldc_i4 _ | Il.Dup | Il.Pop
  | Il.Call _ | Il.Ret | Il.Br _ | Il.Brfalse _ | Il.Brtrue _ | Il.Bcmp _ | Il.Switch _
  | Il.Binop (Il.Add | Il.Sub | Il.Mul | Il.Div | Il.Div_un | Il.Rem | Il.Rem_un
             | Il.And | Il.Or | Il.Xor | Il.Shl | Il.Shr | Il.Shr_un)
  | Il.Neg | Il.Not | Il.Ceq | Il.Cgt _ | Il.Clt _
  | Il.Conv ((Il.K_i1 | Il.K_u1 | Il.K_i2 | Il.K_u2 | Il.K_i4 | Il.K_u4 | Il.K_i | Il.K_u), false, _) -> true
  | _ -> false

(* the methods the JIT takes: each one's own reasons, its stacks (the
 * verifier's: int32s only), its instructions, and its calls, to
 * methods taken too (until no more is dropped) *)
let choose (img : Image.t) : (int, V.result) Hashtbl.t * (int * string) list =
  let taken = Hashtbl.create 16 and refused = ref [] in
  for row = 1 to img.rows.(M.t_method_def) do
    match
      own img row;
      let r = V.method_ img row in
      Array.iteri (fun i (s : V.vt list option) ->
          match s with
          | Some s -> List.iter (fun v -> match v with
              | V.Int32 | V.Native -> ()
              | v -> refuse (sprintf "IL_%04x: %s on the stack" r.instrs.(i).at (V.show v))) s
          | None -> ()) (Array.sub r.stacks 0 (Array.length r.instrs));
      Array.iter (fun (ins : Il.instr) ->
          if not (supported ins.op) then refuse (sprintf "IL_%04x: %s, no template yet" ins.at ins.name);
          match ins.op with
          | Il.Call tok when M.token_table tok <> M.t_method_def ->
              refuse (sprintf "IL_%04x: a call into the library" ins.at)
          | _ -> ()) r.instrs;
      r
    with
    | r -> Hashtbl.replace taken row r
    | exception Refused why -> if why <> "no body" then refused := (row, why) :: !refused
    | exception V.Bad why -> refused := (row, "not verified: " ^ why) :: !refused
  done;
  (* the calls: to a method taken, else the caller is not *)
  let changed = ref true in
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
  let n = Listing.type_name img (M.token M.t_type_def (
      let rec find c = if c > img.rows.(M.t_type_def) then 1
        else let f, l = Image.range img M.t_type_def c "MethodList" M.t_method_def in
          if row >= f && row <= l then c else find (c + 1) in
      find 1)) ^ "_" ^ Image.string img (Image.get img M.t_method_def row "Name") in
  String.map (fun c -> match c with 'a'..'z' | 'A'..'Z' | '0'..'9' -> c | _ -> '_') n

(* the two machines: arm's 5c and arm64's 7c, their names for the same
 * instructions (arm64's W: on the low 32 bits), a word's size *)
type mach = Arm | Arm64

let method_text (m : mach) (img : Image.t) (syms : (int, string) Hashtbl.t) (row : int) (r : V.result) : string =
  let b = Buffer.create 1024 in
  let ins fmt = Printf.ksprintf (fun s -> Buffer.add_string b ("\t" ^ s ^ "\n")) fmt in
  let a64 = m = Arm64 in
  let w = if a64 then 8 else 4 in
  let op s = if a64 then s ^ "W" else s in
  let sym = Hashtbl.find syms row in
  let sg = S.method_ (Image.blob img (Image.get img M.t_method_def row "Signature")) in
  let body = Image.body img (Image.get img M.t_method_def row "RVA") in
  let nlocals =
    if body.locals_token = 0 then 0
    else List.length (S.locals (Image.blob img (Image.get img M.t_stand_alone_sig (M.token_row body.locals_token) "Signature"))) in
  let depth = Array.fold_left (fun d s -> match s with Some s -> max d (List.length s) | None -> d) 0 r.stacks in
  let nslots = depth + 1 in
  (* the outgoing arguments' room: the most a call passes, 5c's way *)
  let maxargs = Array.fold_left (fun a (ins : Il.instr) -> match ins.op with
      | Il.Call tok ->
          let m = S.method_ (Image.blob img (Image.get img M.t_method_def (M.token_row tok) "Signature")) in
          max a (List.length m.params)
      | _ -> a) 1 r.instrs in
  let frame = w * (nslots + nlocals) + w * maxargs in
  (* the places: a stack slot, a local (autos, below SP), an argument
   * (FP: the first one left there from R0 by the prologue's MOVW) *)
  let slot k = sprintf "s%d-%d(SP)" k (w * (k + 1)) in
  let local i = sprintf "l%d-%d(SP)" i (w * (nslots + i + 1)) in
  let arg i = sprintf "a%d+%d(FP)" i (w * i) in
  let label i = sprintf "%s_%d" sym i in
  let targets = Hashtbl.create 8 in
  Array.iter (fun (ins : Il.instr) -> match ins.op with
      | Il.Br t | Il.Brfalse t | Il.Brtrue t | Il.Bcmp (_, _, t) -> Hashtbl.replace targets t ()
      | Il.Switch ts -> Array.iter (fun t -> Hashtbl.replace targets t ()) ts
      | _ -> ()) r.instrs;
  Buffer.add_string b (sprintf "// %s, %d bytes of IL: %d slots, %d locals\n"
                         (Listing.token_name img (M.token M.t_method_def row)) (String.length body.code) nslots nlocals);
  Buffer.add_string b (sprintf "\tTEXT\t%s(SB), 0, $%d\n" sym frame);
  if sg.params <> [] then ins "MOVW\tR0, %s" (arg 0);
  (* the locals zeroed, as .locals init asks (C#'s always does) *)
  if nlocals > 0 then begin
    ins "MOVW\t$0, R1";
    for i = 0 to nlocals - 1 do ins "MOVW\tR1, %s" (local i) done
  end;
  Array.iteri (fun i (x : Il.instr) ->
      if Hashtbl.mem targets i then Buffer.add_string b (label i ^ ":\n");
      Buffer.add_string b (sprintf "\t// IL_%04x: %s\n" x.at x.name);
      let d = match r.stacks.(i) with Some s -> List.length s | None -> 0 in
      (* the top's slot is d - 1, the one under it d - 2 *)
      let top = d - 1 in
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
      match x.op with
      | Il.Nop -> ()
      | Il.Ldarg a -> ins "MOVW\t%s, R1" (arg a); ins "MOVW\tR1, %s" (slot (top + 1))
      | Il.Starg a -> ins "MOVW\t%s, R1" (slot top); ins "MOVW\tR1, %s" (arg a)
      | Il.Ldloc l -> ins "MOVW\t%s, R1" (local l); ins "MOVW\tR1, %s" (slot (top + 1))
      | Il.Stloc l -> ins "MOVW\t%s, R1" (slot top); ins "MOVW\tR1, %s" (local l)
      | Il.Ldc_i4 n -> ins "MOVW\t$%ld, R1" n; ins "MOVW\tR1, %s" (slot (top + 1))
      | Il.Dup -> ins "MOVW\t%s, R1" (slot top); ins "MOVW\tR1, %s" (slot (top + 1))
      | Il.Pop -> ()
      | Il.Binop o ->
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
      | Il.Neg ->
          ins "MOVW\t%s, R1" (slot top);
          if a64 then ins "NEGW\tR1, R1" else ins "RSB\t$0, R1, R1";
          ins "MOVW\tR1, %s" (slot top)
      | Il.Not -> ins "MOVW\t%s, R1" (slot top); ins "%s\tR1, R1" (op "MVN"); ins "MOVW\tR1, %s" (slot top)
      | Il.Ceq | Il.Cgt _ | Il.Clt _ ->
          ins "MOVW\t%s, R1" (slot (top - 1));
          ins "MOVW\t%s, R2" (slot top);
          ins "%s\tR2, R1" (op "CMP");
          set_bool (match x.op with
              | Il.Ceq -> "EQ" | Il.Cgt un -> compare Il.Gt un | Il.Clt un -> compare Il.Lt un | _ -> assert false)
      | Il.Conv (k, _, _) ->
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
      | Il.Br t -> ins "B\t%s" (label t)
      | Il.Brfalse t | Il.Brtrue t ->
          ins "MOVW\t%s, R1" (slot top);
          ins "%s\t$0, R1" (op "CMP");
          ins "%s\t%s" (match x.op with Il.Brtrue _ -> "BNE" | _ -> "BEQ") (label t)
      | Il.Bcmp (c, un, t) ->
          ins "MOVW\t%s, R1" (slot (top - 1));
          ins "MOVW\t%s, R2" (slot top);
          ins "%s\tR2, R1" (op "CMP");
          ins "B%s\t%s" (compare c un) (label t)
      | Il.Switch ts ->
          ins "MOVW\t%s, R1" (slot top);
          Array.iteri (fun k t -> ins "%s\t$%d, R1" (op "CMP") k; ins "BEQ\t%s" (label t)) ts
      | Il.Call tok ->
          (* 5c's and 7c's call: the first argument in R0, the i-th at
           * w(i+1) on the stack; the result in R0 *)
          let callee = M.token_row tok in
          let m' = S.method_ (Image.blob img (Image.get img M.t_method_def callee "Signature")) in
          let n = List.length m'.params in
          for k = n - 1 downto 1 do
            ins "MOVW\t%s, R1" (slot (top - n + 1 + k));
            ins "MOVW\tR1, %d(%s)" (w + w * k) (if a64 then "R31" else "R13")
          done;
          if n > 0 then ins "MOVW\t%s, R0" (slot (top - n + 1));
          ins "BL\t%s(SB)" (Hashtbl.find syms callee);
          if m'.ret <> S.Void then ins "MOVW\tR0, %s" (slot (top - n + 1))
      | Il.Ret ->
          if sg.ret <> S.Void then ins "MOVW\t%s, R0" (slot top);
          ins "%s" (if a64 then "RETURN" else "RET")
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

let assembly (m : mach) (img : Image.t) : string * int * (int * string) list =
  let taken, refused = choose img in
  let rows, syms = symbols img taken in
  let b = Buffer.create 4096 in
  List.iter (fun row -> Buffer.add_string b (method_text m img syms row (Hashtbl.find taken row))) rows;
  (Buffer.contents b, List.length rows, refused)

(* ------------------------------------------------------------------ *)
(* In mini-dotnet: each method's entry an ML function *)
(* ------------------------------------------------------------------ *)

(* An entry, as mini-ml calls a closure of one argument (Gen: the
 * closure in R0, its argument in R1, the result in R0): the argument
 * an array of ints, the method's arguments; each untagged into 7c's
 * places, the method called, its result tagged (2n + 1). The value
 * stack's top (R26) is not touched, the method's slots are all on the
 * machine's stack: they are int32s, which the collector need not see. *)
let entry (img : Image.t) (syms : (int, string) Hashtbl.t) (row : int) : string =
  let b = Buffer.create 256 in
  let ins fmt = Printf.ksprintf (fun s -> Buffer.add_string b ("\t" ^ s ^ "\n")) fmt in
  let sym = Hashtbl.find syms row in
  let sg = S.method_ (Image.blob img (Image.get img M.t_method_def row "Signature")) in
  let n = List.length sg.params in
  Buffer.add_string b (sprintf "\tTEXT\t%s_entry(SB), 0, $%d\n" sym (8 * (n + 1)));
  for k = n - 1 downto 1 do
    ins "MOV\t%d(R1), R2" (8 * k);
    ins "ASR\t$1, R2";
    ins "MOVW\tR2, %d(R31)" (8 + 8 * k)
  done;
  if n > 0 then (ins "MOV\t0(R1), R0"; ins "ASR\t$1, R0");
  ins "BL\t%s(SB)" sym;
  if sg.ret = S.Void then ins "MOV\t$1, R0" else (ins "LSL\t$1, R0"; ins "ORR\t$1, R0");
  ins "RETURN";
  Buffer.contents b

let program (img : Image.t) ~(divide_by_zero : int) : string * (int * string) list =
  let taken, _ = choose img in
  let rows, syms = symbols img taken in
  let b = Buffer.create 4096 in
  List.iter (fun row ->
      Buffer.add_string b (method_text Arm64 img syms row (Hashtbl.find taken row));
      Buffer.add_string b (entry img syms row)) rows;
  (* a division by zero: an ML function of one argument, its closure
   * static, at that address; it raises, and so does not come back *)
  Buffer.add_string b "\tTEXT\tjit_divide_by_zero(SB), $-8\n";
  Buffer.add_string b (sprintf "\tMOV\t$%d, R0\n\tMOV\t$1, R1\n\tMOV\t0(R0), R2\n\tB\t(R2)\n" divide_by_zero);
  (Buffer.contents b, List.map (fun row -> (row, Hashtbl.find syms row ^ "_entry")) rows)
