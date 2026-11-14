(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Machine.mli *)
module M = TinyLibMachine

(*****************************************************************************)
(* The machine: TinyCPU, the stack in r1..r12 *)
(*****************************************************************************)

(* TinyCPU (TinyMachineCPU.ml) has 32-bit registers, r0 zero, no flags, and
 * no unsigned division; its calling convention is ours, simpler than
 * 7c's: every argument in memory, 4 bytes each, the result in r13. The
 * frame, sp at its bottom: the outgoing arguments from 0(sp), the saved
 * lr, the saves of what is live across a call, the locals at its top;
 * above it, the parameters (the caller's outgoing arguments). A
 * variadic function (print) walks its arguments from its last named
 * one's address. *)

(* the result's register, and a scratch one *)
let r13 = 13

(* A function's code as it is made. Its lines, each a function of the
 * frame's size, known at the end; the stack machine's depth (its top
 * register), and the deepest it went; the most registers saved across a
 * call, and the most bytes of a call's arguments; dead after a jump,
 * until a label; the depth at each label jumped to; the variables kept
 * in registers, each its register and its type. *)
type state = {
  mname : Types.sym;
  mlocals : int;
  mutable mlines : (int -> M.line) list;
  mutable msp : int;
  mutable mdeepest : int;
  mutable msaves : int;
  mutable moutgoing : int;
  mutable mdead : bool;
  mdepth_at : (Lower.label, int) Hashtbl.t;
  mregs : (Tree.place * (int * Types.ty)) list;
}

let at (st : state) f = st.mlines <- f :: st.mlines
let emit st (l : M.line) = at st (fun _ -> l)
let ins st (i : M.instr) = emit st (M.Instr i)
let push (st : state) =
  st.msp <- st.msp + 1;
  if st.msp > 12 then Types.error (st.mname ^ ": an expression too deep");
  st.mdeepest <- max st.mdeepest st.msp;
  st.msp
let pop (st : state) = st.msp <- st.msp - 1
let jump (st : state) l = Hashtbl.replace st.mdepth_at l st.msp
let lab (l : Lower.label) = !Types.unit_name ^ ".L" ^ string_of_int l
(* slot k, the k-th save, below the locals *)
let slot (st : state) k = st.mlocals + (4 * k)
(* lr, above the outgoing arguments *)
let epilogue (st : state) =
  at st (fun _ -> M.Instr (M.Load (M.W, M.lr, M.sp, st.moutgoing)));
  at st (fun f -> M.Instr (M.Alui (M.Add, M.sp, M.sp, f)));
  emit st M.Ret

(* a value extended from its type: the registers are 32 bits, so only
 * a char's and a short's need it *)
let extend st (t : Types.ty) a =
  match t with
  | Types.Int (k, s) when k < 4 ->
      if s then
        (ins st (M.Alui (M.Shl, a, a, 32 - (8 * k)));
         ins st (M.Alui (M.Sar, a, a, 32 - (8 * k))))
      else ins st (M.Alui (M.And, a, a, (1 lsl (8 * k)) - 1))
  | _ -> ()

let load st (t : Types.ty) =
  let a = st.msp in
  (match t with
   | Types.Int (1, _) -> ins st (M.Load (M.B, a, a, 0))
   | Types.Int (2, _) ->
       ins st (M.Load (M.B, r13, a, 0));
       ins st (M.Load (M.B, a, a, 1));
       ins st (M.Alui (M.Shl, a, a, 8));
       ins st (M.Alu (M.Or, a, a, r13))
   | _ -> ins st (M.Load (M.W, a, a, 0)));
  extend st t a

let store st (t : Types.ty) =
  let v = st.msp in
  pop st;
  let a = st.msp in
  (match Types.size t with
   | 1 -> ins st (M.Store (M.B, v, a, 0))
   | 2 ->
       ins st (M.Store (M.B, v, a, 0));
       ins st (M.Alui (M.Shr, r13, v, 8));
       ins st (M.Store (M.B, r13, a, 1))
   | _ -> ins st (M.Store (M.W, v, a, 0)));
  emit st (M.Mov (a, v))

(* C's operation, TinyCPU's: / and % on unsigned values by the runtime;
 * a relation of slt and its friends, 1 or 0 *)
let op st (o : Tree.binop) (t : Types.ty) =
  let b = st.msp in
  pop st;
  let a = st.msp and u = Types.unsigned t in
  let slt = if u then M.Sltu else M.Slt in
  let alu op d x y = ins st (M.Alu (op, d, x, y))
  and not_ () = ins st (M.Alui (M.Xor, a, a, 1)) in
  match o with
  | Tree.R Tree.Lt -> alu slt a a b
  | Tree.R Tree.Gt -> alu slt a b a
  | Tree.R Tree.Le -> alu slt a b a; not_ ()
  | Tree.R Tree.Ge -> alu slt a a b; not_ ()
  | Tree.R Tree.Eq -> alu M.Sub a a b; ins st (M.Alui (M.Sltu, a, a, 1))
  | Tree.R Tree.Ne -> alu M.Sub a a b; alu M.Sltu a 0 a
  | Tree.A ((Tree.Div | Tree.Mod) as o) when u ->
      (* TinyCPU divides signed only: the runtime's __udivmod, its
       * operands and the remainder below sp, the quotient in r13 *)
      ins st (M.Store (M.W, a, M.sp, -4));
      ins st (M.Store (M.W, b, M.sp, -8));
      emit st (M.Call "__udivmod");
      if o = Tree.Div then emit st (M.Mov (a, r13))
      else ins st (M.Load (M.W, a, M.sp, -4));
      extend st t a
  | Tree.A o ->
      alu
        (match o with
         | Tree.Add -> M.Add | Tree.Sub -> M.Sub | Tree.Mul -> M.Mul
         | Tree.Div -> M.Div | Tree.Mod -> M.Rem | Tree.And -> M.And
         | Tree.Or -> M.Or | Tree.Xor -> M.Xor | Tree.Shl -> M.Shl
         | Tree.Shr -> if u then M.Shr else M.Sar)
        a a b;
      extend st t a

(* A variable's address, in register a: a local's below the frame's top,
 * a parameter's above it (the frame's size f known at the end). *)
let address st (p : Tree.place) a =
  match p with
  | Tree.Global s -> emit st (M.La (a, s))
  | Tree.Local o -> at st (fun f -> M.Instr (M.Alui (M.Add, a, M.sp, f - o)))
  | Tree.Param o -> at st (fun f -> M.Instr (M.Alui (M.Add, a, M.sp, f + o)))

(* A variable kept in register r is caller-saved: its home in the frame
 * is written before a call and read back after it, as the stack's
 * registers are. *)
let home p f = match p with Tree.Param o -> f + o | Tree.Local o -> f - o | _ -> 0
let size (t : Types.ty) = if Types.size t = 1 then M.B else M.W
let save st =
  List.iter (fun (p, (r, t)) ->
    at st (fun f -> M.Instr (M.Store (size t, r, M.sp, home p f)))) st.mregs
let restore st regs =
  List.iter (fun (p, (r, t)) ->
    at st (fun f -> M.Instr (M.Load (size t, r, M.sp, home p f)));
    extend st t r) regs

(* a call of f, or of the address on top of the arguments: the registers
 * below them saved in their slots, the arguments in memory *)
let call st (f : Types.sym option) k res =
  let base = st.msp - k - (if f = None then 1 else 0) in
  st.msaves <- max st.msaves base;
  for j = 1 to base do
    at st (fun fr -> M.Instr (M.Store (M.W, j, M.sp, fr - slot st j)))
  done;
  for j = 0 to k - 1 do
    ins st (M.Store (M.W, base + 1 + j, M.sp, 4 * j))
  done;
  st.moutgoing <- max st.moutgoing (4 * k);
  save st;
  (match f with
   | Some f -> emit st (M.Call f)
   | None -> ins st (M.Jalr (M.lr, base + k + 1, 0)));
  for j = 1 to base do
    at st (fun fr -> M.Instr (M.Load (M.W, j, M.sp, fr - slot st j)))
  done;
  restore st st.mregs;
  st.msp <- base;
  if res then (let d = push st in emit st (M.Mov (d, r13)))

(* a jump if the top is zero (Eq), or not (Ne) *)
let branch st c l =
  let a = st.msp in
  pop st; jump st l; emit st (M.Branch_to (c, a, 0, lab l))

let instruction (st : state) (i : Lower.ir) =
  match i with
  | Lower.Label l ->
      (match Hashtbl.find_opt st.mdepth_at l with
       | Some d when st.mdead -> st.msp <- d
       | _ -> ());
      st.mdead <- false;
      emit st (M.Label (lab l))
  | _ when st.mdead -> ()
  | Lower.Imm v -> let a = push st in emit st (M.Li (a, Int64.to_int32 v))
  | Lower.Place p -> address st p (push st)
  (* a variable without a register is read and written in memory, as
   * Place with Load or Store would *)
  | Lower.Get (p, t) ->
      (match List.assoc_opt p st.mregs with
       | Some (r, _) -> let a = push st in emit st (M.Mov (a, r))
       | None -> address st p (push st); load st t)
  | Lower.Set (p, t) ->
      let v = st.msp in
      (match List.assoc_opt p st.mregs with
       | Some (r, _) -> emit st (M.Mov (r, v)); extend st t r
       | None ->
           let a = push st in
           address st p a;
           ins st (M.Store (size t, v, a, 0));
           pop st)
  | Lower.Load t -> load st t
  | Lower.Store t -> store st t
  | Lower.Op (o, t) -> op st o t
  | Lower.Unop (o, t) ->
      let a = st.msp in
      if o = Tree.Neg then ins st (M.Alu (M.Sub, a, 0, a))
      else
        (ins st (M.Alui (M.Add, r13, 0, -1));
         ins st (M.Alu (M.Xor, a, a, r13)));
      extend st t a
  | Lower.Ext t -> extend st t st.msp
  | Lower.Dup ->
      let a = st.msp in
      let d = push st in
      emit st (M.Mov (d, a))
  | Lower.Drop -> pop st
  | Lower.Call (f, k, res) -> call st f k res
  | Lower.Jmp l -> jump st l; emit st (M.Jump (lab l)); st.mdead <- true
  | Lower.Jz l -> branch st M.Eq l
  | Lower.Jnz l -> branch st M.Ne l
  | Lower.Ret v ->
      if v then (emit st (M.Mov (r13, st.msp)); pop st);
      epilogue st;
      st.mdead <- true

let run name locals regs body =
  let st =
    { mname = name; mlocals = locals; mlines = []; msp = 0; mdeepest = 0;
      msaves = 0; moutgoing = 0; mdead = false;
      mdepth_at = Hashtbl.create 16; mregs = regs } in
  (* the parameters kept in registers, read from their homes *)
  restore st
    (List.filter (fun (p, _) ->
       match p with Tree.Param _ -> true | _ -> false) regs);
  List.iter (instruction st) body;
  if not st.mdead then epilogue st;
  st

(* The stack's registers that the function's code never reaches keep its
 * variables, the heaviest first: a first run, with every variable in
 * memory, tells how deep the stack goes (a variable in a register only
 * makes it shallower), and the second run gives the variables the
 * registers above that depth, up to r12.
 *
 * opti: every variable used to live in its frame's slot, a read being
 * its address and a load, a write its address and a store; a loop that
 * copies bytes took 31 instructions a byte, 23 now
 * (plan_tiny_self_speed.md, step 3).
 *
 * old: a single run, with no registers: [run name locals [] body]. *)
let machine (name : Types.sym) locals
    ((body, vars) : Lower.ir list * (Tree.place * (Types.ty * int)) list)
    : M.line list =
  let deepest = (run name locals [] body).mdeepest in
  let regs =
    List.filteri (fun i _ -> deepest + 1 + i <= 12) vars
    |> List.mapi (fun i (p, (t, _)) -> p, (deepest + 1 + i, t)) in
  let st = run name locals regs body in
  let frame = Types.round (st.moutgoing + 4 + (4 * st.msaves) + locals) 8 in
  [ M.Label name;
    M.Instr (M.Alui (M.Add, M.sp, M.sp, - frame));
    M.Instr (M.Store (M.W, M.lr, M.sp, st.moutgoing)) ]
  @ List.rev_map (fun f -> f frame) st.mlines

(*****************************************************************************)
(* The data: the globals *)
(*****************************************************************************)

(* [global g n ds]: a global of n bytes, its label and its data at their
 * offsets, the gaps zeros *)
let global (name : Types.sym) size (ds : (int * Tree.datum) list)
    : M.line list =
  let out = ref [ M.Label name; M.Align 4 ] in
  let line l = out := l :: !out in
  let at =
    ds
    |> List.sort (fun (a, _) (b, _) -> compare a b)
    |> List.fold_left (fun at (off, d) ->
      if off > at then line (M.Space (off - at));
      match d with
      | Tree.Bytes b ->
          line (M.Bytes
                  (List.map Char.code
                     (List.init (String.length b) (String.get b))));
          off + String.length b
      | Tree.Value (1, v) ->
          line (M.Bytes [ Int64.to_int v land 0xff ]); off + 1
      | Tree.Value (2, v) ->
          line (M.Bytes [ Int64.to_int v land 0xff;
                            (Int64.to_int v lsr 8) land 0xff ]);
          off + 2
      | Tree.Value (k, v) ->
          line (M.Word (Int64.to_int32 v));
          if k = 8 then line (M.Word (Int64.to_int32 (Int64.shift_right v 32)));
          off + k
      | Tree.Address s -> line (M.Word_sym s); off + 4
      ) 0 in
  if size > at then line (M.Space (size - at));
  List.rev !out
