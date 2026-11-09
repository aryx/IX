(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyCMachine.mli *)
module Ty = TinyCTypes
module Tree = TinyCTree
module Lower = TinyCLower

(*****************************************************************************)
(* The machine: TinyCPU, the stack in r1..r12 *)
(*****************************************************************************)

(* a value's low 32 bits, signed, in decimal, as the assembly writes a
 * word (old: Printf's %ld of Int64.to_int32) *)
let word v = Int64.to_string (Int64.shift_right (Int64.shift_left v 32) 32)

(* a register's name, a number's text (old: Printf's formats, %d) *)
let r k = Printf.sprintf "r%d" k
let n k = string_of_int k

(* TinyCPU (TinyMachineCPU.ml) has 32-bit registers, r0 zero, no flags, and
 * no unsigned division; its calling convention is ours, simpler than
 * 7c's: every argument in memory, 4 bytes each, the result in r13. The
 * frame, sp at its bottom: the outgoing arguments from 0(sp), the saved
 * lr, the saves of what is live across a call, the locals at its top;
 * above it, the parameters (the caller's outgoing arguments). A
 * variadic function (print) walks its arguments from its last named
 * one's address. *)

(* A function's code as it is made. Its lines, each a function of the
 * frame's size, known at the end; the stack machine's depth (its top
 * register); the most registers saved across a call, and the most bytes
 * of a call's arguments; dead after a jump, until a label; the depth at
 * each label jumped to. (old: refs local to machine) *)
type state = {
  mname : Ty.sym;
  mlocals : int;
  mutable mlines : (int -> string) list;
  mutable msp : int;
  mutable msaves : int;
  mutable moutgoing : int;
  mutable mdead : bool;
  mdepth_at : (Lower.label, int) Hashtbl.t;
}

let at (st : state) f = st.mlines <- f :: st.mlines
let ins st s = at st (fun _ -> Printf.sprintf "\t%s\n" s)
let push (st : state) =
  st.msp <- st.msp + 1;
  if st.msp > 12 then Ty.error (st.mname ^ ": an expression too deep");
  st.msp
let pop (st : state) = st.msp <- st.msp - 1
let jump (st : state) l = Hashtbl.replace st.mdepth_at l st.msp
let lab (l : Lower.label) = !Ty.unit_name ^ ".L" ^ string_of_int l
(* slot k, the k-th save, below the locals *)
let slot (st : state) k = st.mlocals + (4 * k)
(* an instruction of three registers *)
let three st op a b c = ins st (op ^ "\t" ^ r a ^ ", " ^ r b ^ ", " ^ r c)
(* lr, above the outgoing arguments *)
let epilogue (st : state) =
  at st (fun f ->
    "\tldw\tlr, " ^ n st.moutgoing ^ "(sp)\n\taddi\tsp, sp, " ^ n f
    ^ "\n\tret\n")

(* a value extended from its type: the registers are 32 bits, so only
 * a char's and a short's need it *)
let extend st (t : Ty.ty) a =
  match t with
  | Ty.Int (k, s) when k < 4 ->
      if s then
        (ins st ("shli\t" ^ r a ^ ", " ^ r a ^ ", " ^ n (32 - (8 * k)));
         ins st ("sari\t" ^ r a ^ ", " ^ r a ^ ", " ^ n (32 - (8 * k))))
      else ins st ("andi\t" ^ r a ^ ", " ^ r a ^ ", " ^ n ((1 lsl (8 * k)) - 1))
  | _ -> ()

let load st (t : Ty.ty) =
  let a = st.msp in
  (match t with
   | Ty.Int (1, _) -> ins st ("ldb\t" ^ r a ^ ", 0(" ^ r a ^ ")")
   | Ty.Int (2, _) ->
       ins st ("ldb\tr13, 0(" ^ r a ^ ")");
       ins st ("ldb\t" ^ r a ^ ", 1(" ^ r a ^ ")");
       ins st ("shli\t" ^ r a ^ ", " ^ r a ^ ", 8");
       ins st ("or\t" ^ r a ^ ", " ^ r a ^ ", r13")
   | _ -> ins st ("ldw\t" ^ r a ^ ", 0(" ^ r a ^ ")"));
  extend st t a

let store st (t : Ty.ty) =
  let v = st.msp in
  pop st;
  let a = st.msp in
  (match Ty.size t with
   | 1 -> ins st ("stb\t" ^ r v ^ ", 0(" ^ r a ^ ")")
   | 2 ->
       ins st ("stb\t" ^ r v ^ ", 0(" ^ r a ^ ")");
       ins st ("shri\tr13, " ^ r v ^ ", 8");
       ins st ("stb\tr13, 1(" ^ r a ^ ")")
   | _ -> ins st ("stw\t" ^ r v ^ ", 0(" ^ r a ^ ")"));
  ins st ("mov\t" ^ r a ^ ", " ^ r v)

let op st (o : Tree.binop) (t : Ty.ty) =
  let b = st.msp in
  pop st;
  let a = st.msp and u = Ty.unsigned t in
  let slt = if u then "sltu" else "slt" in
  match o with
  | Tree.R Tree.Lt -> three st slt a a b
  | Tree.R Tree.Gt -> three st slt a b a
  | Tree.R Tree.Le ->
      three st slt a b a; ins st ("xori\t" ^ r a ^ ", " ^ r a ^ ", 1")
  | Tree.R Tree.Ge ->
      three st slt a a b; ins st ("xori\t" ^ r a ^ ", " ^ r a ^ ", 1")
  | Tree.R Tree.Eq ->
      three st "sub" a a b; ins st ("sltiu\t" ^ r a ^ ", " ^ r a ^ ", 1")
  | Tree.R Tree.Ne ->
      three st "sub" a a b; ins st ("sltu\t" ^ r a ^ ", zero, " ^ r a)
  | Tree.A ((Tree.Div | Tree.Mod) as o) when u ->
      (* TinyCPU divides signed only: the runtime's __udivmod, its
       * operands and the remainder below sp, the quotient in r13 *)
      ins st ("stw\t" ^ r a ^ ", -4(sp)"); ins st ("stw\t" ^ r b ^ ", -8(sp)");
      ins st "call\t__udivmod";
      if o = Tree.Div then ins st ("mov\t" ^ r a ^ ", r13")
      else ins st ("ldw\t" ^ r a ^ ", -4(sp)");
      extend st t a
  | Tree.A o ->
      three st
        (match o with
         | Tree.Add -> "add" | Tree.Sub -> "sub" | Tree.Mul -> "mul"
         | Tree.Div -> "div" | Tree.Mod -> "rem" | Tree.And -> "and"
         | Tree.Or -> "or" | Tree.Xor -> "xor" | Tree.Shl -> "shl"
         | Tree.Shr -> if u then "shr" else "sar")
        a a b;
      extend st t a

(* a call of f, or of the address on top of the arguments: the registers
 * below them saved in their slots, the arguments in memory *)
let call st (f : Ty.sym option) k res =
  let base = st.msp - k - (if f = None then 1 else 0) in
  st.msaves <- max st.msaves base;
  for j = 1 to base do
    at st (fun fr -> "\tstw\t" ^ r j ^ ", " ^ n (fr - slot st j) ^ "(sp)\n")
  done;
  for j = 0 to k - 1 do
    ins st ("stw\t" ^ r (base + 1 + j) ^ ", " ^ n (4 * j) ^ "(sp)")
  done;
  st.moutgoing <- max st.moutgoing (4 * k);
  (match f with
   | Some f -> ins st ("call\t" ^ f)
   | None -> ins st ("jalr\tlr, 0(" ^ r (base + k + 1) ^ ")"));
  for j = 1 to base do
    at st (fun fr -> "\tldw\t" ^ r j ^ ", " ^ n (fr - slot st j) ^ "(sp)\n")
  done;
  st.msp <- base;
  if res then (let d = push st in ins st ("mov\t" ^ r d ^ ", r13"))

(* a jump if the top is zero (beq), or not (bne) *)
let branch st b l =
  let a = st.msp in
  pop st; jump st l; ins st (b ^ "\t" ^ r a ^ ", zero, " ^ lab l)

let instruction (st : state) (i : Lower.ir) =
  match i with
  | Lower.Label l ->
      (match Hashtbl.find_opt st.mdepth_at l with
       | Some d when st.mdead -> st.msp <- d
       | _ -> ());
      st.mdead <- false;
      at st (fun _ -> lab l ^ ":\n")
  | _ when st.mdead -> ()
  | Lower.Imm v -> let a = push st in ins st ("li\t" ^ r a ^ ", " ^ word v)
  | Lower.Place (Tree.Global s) ->
      let a = push st in ins st ("la\t" ^ r a ^ ", " ^ s)
  | Lower.Place (Tree.Local o) ->
      let a = push st in
      at st (fun f -> "\taddi\t" ^ r a ^ ", sp, " ^ n (f - o) ^ "\n")
  | Lower.Place (Tree.Param o) ->
      let a = push st in
      at st (fun f -> "\taddi\t" ^ r a ^ ", sp, " ^ n (f + o) ^ "\n")
  | Lower.Load t -> load st t
  | Lower.Store t -> store st t
  | Lower.Op (o, t) -> op st o t
  | Lower.Unop (o, t) ->
      let a = st.msp in
      if o = Tree.Neg then ins st ("sub\t" ^ r a ^ ", zero, " ^ r a)
      else
        (ins st "addi\tr13, zero, -1";
         ins st ("xor\t" ^ r a ^ ", " ^ r a ^ ", r13"));
      extend st t a
  | Lower.Ext t -> extend st t st.msp
  | Lower.Dup ->
      let a = st.msp in
      let d = push st in
      ins st ("mov\t" ^ r d ^ ", " ^ r a)
  | Lower.Drop -> pop st
  | Lower.Call (f, k, res) -> call st f k res
  | Lower.Jmp l -> jump st l; ins st ("j\t" ^ lab l); st.mdead <- true
  | Lower.Jz l -> branch st "beq" l
  | Lower.Jnz l -> branch st "bne" l
  | Lower.Ret v ->
      if v then (ins st ("mov\tr13, " ^ r st.msp); pop st);
      epilogue st;
      st.mdead <- true

let machine (name : Ty.sym) locals (body : Lower.ir list) : string =
  let st =
    { mname = name; mlocals = locals; mlines = []; msp = 0; msaves = 0;
      moutgoing = 0; mdead = false; mdepth_at = Hashtbl.create 16 } in
  List.iter (instruction st) body;
  if not st.mdead then epilogue st;
  let frame = Ty.round (st.moutgoing + 4 + (4 * st.msaves) + locals) 8 in
  name ^ ":\n\taddi\tsp, sp, " ^ n (- frame) ^ "\n\tstw\tlr, "
  ^ n st.moutgoing ^ "(sp)\n"
  ^ String.concat "" (List.rev_map (fun f -> f frame) st.mlines)

(*****************************************************************************)
(* The data: the globals *)
(*****************************************************************************)

(* [global g n ds]: a global of n bytes, its label and its data at their
 * offsets, the gaps zeros *)
let global (name : Ty.sym) size (ds : (int * Tree.datum) list) : string =
  let out = Buffer.create 64 in
  let line s = Printf.bprintf out "\t%s\n" s in
  Buffer.add_string out ("\t.align\t4\n" ^ name ^ ":\n");
  let bytes l =
    line (".byte\t" ^ String.concat ", " (List.map string_of_int l)) in
  let at =
    ds
    |> List.sort (fun (a, _) (b, _) -> compare a b)
    |> List.fold_left (fun at (off, d) ->
      if off > at then line (Printf.sprintf ".space\t%d" (off - at));
      match d with
      | Tree.Bytes b ->
          bytes
            (List.map Char.code (List.init (String.length b) (String.get b)));
          off + String.length b
      | Tree.Value (1, v) -> bytes [ Int64.to_int v land 0xff ]; off + 1
      | Tree.Value (2, v) ->
          bytes [ Int64.to_int v land 0xff; (Int64.to_int v lsr 8) land 0xff ];
          off + 2
      | Tree.Value (k, v) ->
          line (".word\t" ^ word v);
          if k = 8 then line (".word\t" ^ word (Int64.shift_right v 32));
          off + k
      | Tree.Address s -> line (".word\t" ^ s); off + 4
      ) 0 in
  if size > at then line (Printf.sprintf ".space\t%d" (size - at));
  Buffer.contents out
