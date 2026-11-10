(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMLMachine.mli *)
module Lexer = TinyMLLexer
module Tree = TinyMLTree
module ISA = TinyMachineISA
module Asm = TinyMachineAsm

(*****************************************************************************)
(* The stack machine *)
(*****************************************************************************)

type rel = Eq | Ne | Lt | Le | Gt | Ge
type op =
  | Add | Sub | Mul | Div | Mod | And | Or | Xor | Lsl | Lsr | Asr | Cmp of rel
  | Neg | Lnot | Not | IsInt | Tag
(* an assembly's label: a function's code, a static block, a string
 * (old: a string, which said nothing of it) *)
type sym = string

(* a function's n-ary code, or a closure's field (Indirect, old: Code,
 * which tiny-ml took for Exit.Code: one name space for the
 * constructors) *)
type target = Direct of sym | Indirect of int

(* a word's 32 bits, signed: what the machine keeps of an int64 *)
let low32 v = Int64.shift_right (Int64.shift_left v 32) 32

(* a place in a function's code, a number *)
type label = int
(* a slot of the function's frame on the value stack: 0 its closure,
 * then its parameters and its variables *)
type slot = int

(* a binary operation's first operand is on top, as every operation's:
 * arguments are pushed from the last, as OCaml evaluates them *)
type ir =
  | Imm of int64                      (* a word, an integer already tagged *)
  | Addr of sym                       (* a symbol's address: a static block's
                                       * is its value *)
  | Get of slot | Set of slot
  | GetG of sym * int | SetG of sym * int   (* a global of a unit: its
                                             * table, its index *)
  | Field of int                      (* a block by its field *)
  | SetField of int                   (* the value below the block stored in
                                       * its field *)
  | Alloc of int * int                (* a tag, n values by the block of them,
                                       * the top its field 0 *)
  | Blank of int * int                (* a tag, a block of n fields, each () *)
  | Op of op
  | Call of target * int * bool       (* the closure then n arguments by the
                                       * result; a tail call *)
  | CallC of sym * int                (* a runtime's function of n arguments *)
  | Label of label | Jmp of label
  | Jz of label | Jnz of label        (* false is 1, the tagged 0 *)
  | Drop
  | Ret
  | Raise                             (* the top raised; its place taken by the
                                       * result, never seen *)
  | TryEnter of int * label           (* the k-th handler of the function, its
                                       * code *)
  | TryExit of int
  | Catch of int
    (* the handler's entry: the exception pushed *)


let labels = ref 0
let label () : label = incr labels; !labels
(* A unit's assembly, or the whole program's, as it is made: its
 * functions' code, its static blocks' data, their lines printed (old:
 * two buffers, text and data, which TinyML.ml cleared and read) *)
type asm = { text : Buffer.t; data : Buffer.t }

(* the assembly being made: what the code (machine's, add_text) and the
 * static blocks (words, block) go to; one at a time, as the units are
 * compiled one after the other *)
let current =
  ref { text = Buffer.create 0; data = Buffer.create 0 }

(* a new assembly, from then on the current one *)
let start_asm () : asm =
  let a = { text = Buffer.create 65536; data = Buffer.create 16384 } in
  current := a;
  a

(* lines added to the current assembly's code, or to its data *)
let add_text (ls : Asm.line list) =
  List.iter (fun l -> Buffer.add_string !current.text (Asm.print l)) ls
let add_data (ls : Asm.line list) =
  List.iter (fun l -> Buffer.add_string !current.data (Asm.print l)) ls

(* its text, for tiny-assembler: the code, then the data (.data) *)
let asm_text (a : asm) : string =
  Buffer.contents a.text ^ Asm.print Asm.SectionData ^ Buffer.contents a.data

(*****************************************************************************)
(* The machine: tiny-machine, the stack in r1..r11, the value stack at r12 *)
(*****************************************************************************)

(* TinyMachineCPU's CPU: 32-bit registers, r0 zero, no flags, sp r14, lr
 * r15; words of 4 bytes, so an integer of 31 bits (a constant beyond
 * them is refused) and a block's fields 4 bytes each. The stack
 * machine's registers are r1..r11 (an expression 11 deep at most), the
 * value stack's top is r12, r13 the scratch and the result. A
 * function's frames, in words of 4 bytes. On the value stack, f words
 * below r12 (its top, which the function raises by f at its entry):
 * slot 0 its closure, then its parameters, its variables, and a slot
 * per register of the stack machine, where a call or an allocation
 * spills it. On the machine stack, m bytes: C's outgoing arguments from
 * 0(sp) (tiny-c's convention: every argument in memory, the result in
 * r13, every register but sp the callee's), the link at c, then 16
 * bytes per handler. A call of ML passes the closure in r13 and the
 * arguments in r1..rn (r0 is the zero), so at most 10 (r11 is a tail
 * call's target); the result is in r13. Every call is la then jalr: a
 * jal reaches only 128 KB, and a kernel with its runtime and its
 * programs is bigger. After a call of C, r12 comes back from ml_vsp (C
 * keeps no register). *)

(* the registers by their roles: the value stack's top, the scratch and
 * the result, a tail call's target; lr is also a scratch one *)
let vsp = 12 and r13 = 13 and r11 = 11
let lr = ISA.lr and sp = ISA.sp

(* a line as it is made: known, or made of the frame's sizes (f, m, c),
 * known at the end (old: the text, in a buffer, between two lines of
 * the frame, each a function) *)
type made = Known of Asm.line | Framed of (int -> int -> int -> Asm.line)

(* A function's code as it is made. Its lines, the last first; the
 * stack machine's depth (its top register) and the deepest; the
 * handlers and the words of C's arguments, the most of a call; dead
 * after a jump, until a label; the depth at each label jumped to, and
 * at each handler. (old: refs local to machine, its 320 lines a
 * closure each; the lines strings, Printf's) *)
type state = {
  mname : sym;
  mslots : int;
  mutable mlines : made list;
  mutable msp : int;
  mutable mmaxsp : int;
  mutable mtries : int;
  mutable mcargs : int;
  mutable mdead : bool;
  mdepth_at : (label, int) Hashtbl.t;
  mcatch_at : (int, int) Hashtbl.t;
}

let emit (st : state) (l : Asm.line) = st.mlines <- Known l :: st.mlines
let ins st (i : ISA.instr) = emit st (Asm.Instr i)
let framed (st : state) f = st.mlines <- Framed f :: st.mlines

(* a slot to a register, and back, at r12, the frame's top *)
let get st (i : slot) r =
  framed st (fun f _ _ -> Asm.Instr (ISA.Load (ISA.W, r, vsp, 4 * (i - f))))
let put st r (i : slot) =
  framed st (fun f _ _ -> Asm.Instr (ISA.Store (ISA.W, r, vsp, 4 * (i - f))))
(* where a register is spilled *)
let spill_slot (st : state) r : slot = st.mslots + r - 1
let push (st : state) =
  st.msp <- st.msp + 1;
  if st.msp > 11 then
    Lexer.error
      (st.mname
       ^ ": an expression too deep (tiny-machine has 11 registers for it)");
  st.mmaxsp <- max st.mmaxsp st.msp;
  st.msp
let pop (st : state) = st.msp <- st.msp - 1
let spill (st : state) =
  for r = 1 to st.msp do put st r (spill_slot st r) done
let reload (st : state) =
  for r = 1 to st.msp do get st (spill_slot st r) r done
(* r13, a call's result, pushed *)
let result st = emit st (Asm.Mov (push st, r13))
let lab (l : label) = !Tree.unit_name ^ ".L" ^ string_of_int l
let jump (st : state) l = Hashtbl.replace st.mdepth_at l st.msp
let epilogue st =
  framed st (fun f _ _ -> Asm.Instr (ISA.Alui (ISA.Add, vsp, vsp, -4 * f)));
  framed st (fun _ _ c -> Asm.Instr (ISA.Load (ISA.W, lr, sp, c)));
  framed st (fun _ m _ -> Asm.Instr (ISA.Alui (ISA.Add, sp, sp, m)))
(* the k-th handler's record on the machine stack, above the link *)
let record c k = c + 4 + (16 * k)
(* an instruction at the offset d of the k-th handler's record *)
let at st k d (f : int -> ISA.instr) =
  framed st (fun _ _ c -> Asm.Instr (f (record c k + d)))
let c_call st f =
  emit st (Asm.La (lr, "ml_vsp")); ins st (ISA.Store (ISA.W, vsp, lr, 0));
  emit st (Asm.La (lr, f)); ins st (ISA.Jalr (lr, lr, 0));
  emit st (Asm.La (lr, "ml_vsp")); ins st (ISA.Load (ISA.W, vsp, lr, 0))
(* a binary operation's registers, the result in the second *)
let bin (st : state) f = let a = st.msp in pop st; f a st.msp
(* the integer in register d tagged *)
let tag_int st d =
  ins st (ISA.Alui (ISA.Shl, d, d, 1));
  ins st (ISA.Alui (ISA.Or, d, d, 1))

(* an operation on tagged integers: 2n+1 *)
let op (st : state) o =
  let ins = ins st and bin = bin st and tagged = tag_int st in
  let alu op d a b = ins (ISA.Alu (op, d, a, b))
  and alui op d a k = ins (ISA.Alui (op, d, a, k)) in
  let a = st.msp in
  match o with
  | Add -> bin (fun a b -> alu ISA.Add b a b; alui ISA.Add b b (-1))
  | Sub -> bin (fun a b -> alu ISA.Sub b a b; alui ISA.Add b b 1)
  | Mul ->
      bin (fun a b ->
        alui ISA.Add a a (-1); alui ISA.Sar b b 1; alu ISA.Mul b a b;
        alui ISA.Add b b 1)
  | Div | Mod ->
      bin (fun a b ->
        alui ISA.Sar a a 1; alui ISA.Sar b b 1;
        alu (if o = Div then ISA.Div else ISA.Rem) b a b;
        tagged b)
  | And -> bin (fun a b -> alu ISA.And b a b)
  | Or -> bin (fun a b -> alu ISA.Or b a b)
  | Xor -> bin (fun a b -> alu ISA.Xor b a b; alui ISA.Or b b 1)
  | Lsl ->
      bin (fun a b ->
        alui ISA.Add a a (-1); alui ISA.Sar b b 1; alu ISA.Shl b a b;
        alui ISA.Or b b 1)
  | Lsr | Asr ->
      bin (fun a b ->
        alui ISA.Sar b b 1;
        alu (if o = Lsr then ISA.Shr else ISA.Sar) b a b;
        alui ISA.Or b b 1)
  | Cmp r ->
      (* a r b, 1 or 0, then tagged *)
      bin (fun a b ->
        (match r with
         | Lt -> alu ISA.Slt b a b
         | Gt -> alu ISA.Slt b b a
         | Le -> alu ISA.Slt b b a; alui ISA.Xor b b 1
         | Ge -> alu ISA.Slt b a b; alui ISA.Xor b b 1
         | Eq -> alu ISA.Sub b a b; alui ISA.Sltu b b 1
         | Ne -> alu ISA.Sub b a b; alu ISA.Sltu b 0 b);
        tagged b)
  | Neg -> alu ISA.Sub a 0 a; alui ISA.Add a a 2
  | Lnot -> alui ISA.Add r13 0 (-1); alu ISA.Xor a a r13; alui ISA.Or a a 1
  | Not -> alui ISA.Xor a a 2
  | IsInt -> alui ISA.And a a 1; tagged a
  | Tag -> ins (ISA.Load (ISA.B, a, a, -4)); tagged a

(* a block of n fields from the runtime, in r13 *)
let alloc (st : state) tag n =
  spill st;
  st.mcargs <- max st.mcargs 2;
  emit st (Asm.Li (r13, Int64.of_int n));
  ins st (ISA.Store (ISA.W, r13, sp, 0));
  emit st (Asm.Li (r13, Int64.of_int tag));
  ins st (ISA.Store (ISA.W, r13, sp, 4));
  c_call st "ml_alloc"

(* a call of ML: the closure in r13, the arguments in r1..rn *)
let call (st : state) t n tail =
  if n > 10 then
    Lexer.error
      (st.mname ^ ": " ^ string_of_int n
       ^ " arguments (tiny-machine passes 10 at most)");
  spill st;
  get st (spill_slot st st.msp) r13;
  for k = 1 to n do get st (spill_slot st (st.msp - k)) k done;
  st.msp <- st.msp - n - 1;
  (* the code's address in r, then a jump to it, with the link in d *)
  let go r d =
    (match t with
     | Direct f -> emit st (Asm.La (r, f))
     | Indirect k -> ins st (ISA.Load (ISA.W, r, r13, 4 * k)));
    ins st (ISA.Jalr (d, r, 0)) in
  if tail then begin
    epilogue st;
    go r11 0;
    st.mdead <- true
  end
  else begin
    go lr lr;
    reload st;
    result st
  end

(* a call of C, the runtime's: the arguments in memory *)
let call_c (st : state) f n =
  spill st;
  st.mcargs <- max st.mcargs n;
  for k = 0 to n - 1 do
    get st (spill_slot st (st.msp - k)) r13;
    ins st (ISA.Store (ISA.W, r13, sp, 4 * k))
  done;
  st.msp <- st.msp - n;
  c_call st f;
  reload st;
  result st

(* A string's length and its bytes are read inline rather than by a
 * call of the runtime: a call for each byte was a quarter of the time
 * a browser took to read a page (plan_tiny_browser.md, section 12).
 * The length comes from the block's header and its last byte, as in
 * TinyMLRuntime/core.c's length. Only r13 and lr are free here (lr
 * is saved by the prologue). *)

(* the length of the string in register s, untagged, into r13; lr used *)
let length_of st s =
  ins st (ISA.Load (ISA.W, r13, s, -4));
  ins st (ISA.Alui (ISA.Shr, r13, r13, 10));
  ins st (ISA.Alui (ISA.Shl, r13, r13, 2));
  ins st (ISA.Alu (ISA.Add, lr, s, r13));
  ins st (ISA.Load (ISA.B, lr, lr, -1));
  ins st (ISA.Alu (ISA.Sub, r13, r13, lr));
  ins st (ISA.Alui (ISA.Add, r13, r13, -1))

let string_length (st : state) =
  length_of st st.msp;
  emit st (Asm.Mov (st.msp, r13));
  tag_int st st.msp

(* s.[i]: s is on top of the stack, i below it, and the byte takes i's
 * register. The index is checked against the length; only an index out
 * of bounds calls ml_string_get, which reports the error. *)
let string_get (st : state) =
  let s = st.msp and i = st.msp - 1 in
  let slow = label () and done_ = label () in
  length_of st s;
  ins st (ISA.Alui (ISA.Sar, lr, i, 1));
  emit st (Asm.Branch (ISA.Geu, lr, r13, lab slow));
  ins st (ISA.Alu (ISA.Add, lr, s, lr));
  ins st (ISA.Load (ISA.B, i, lr, 0));
  tag_int st i;
  emit st (Asm.Jump (lab done_));
  emit st (Asm.Label (lab slow));
  call_c st "ml_string_get" 2;
  emit st (Asm.Label (lab done_))

(* a jump if the top is false, the tagged 0 (Eq), or true (Ne) *)
let branch (st : state) c l =
  let r = st.msp in
  pop st; jump st l; emit st (Asm.Li (r13, Int64.one));
  emit st (Asm.Branch (c, r, r13, lab l))

(* the handler's record: sp, r12, the handler's address (call's link:
 * the j after it), the previous record *)
let try_enter (st : state) k handler =
  spill st;
  Hashtbl.replace st.mcatch_at k st.msp;
  st.mtries <- max st.mtries (k + 1);
  let set = label () in
  emit st (Asm.Call (lab set));
  emit st (Asm.Jump (lab handler));
  emit st (Asm.Label (lab set));
  at st k 0 (fun o -> ISA.Store (ISA.W, sp, sp, o));
  at st k 4 (fun o -> ISA.Store (ISA.W, vsp, sp, o));
  at st k 8 (fun o -> ISA.Store (ISA.W, lr, sp, o));
  emit st (Asm.La (lr, "ml_handler"));
  ins st (ISA.Load (ISA.W, r13, lr, 0));
  at st k 12 (fun o -> ISA.Store (ISA.W, r13, sp, o));
  at st k 0 (fun o -> ISA.Alui (ISA.Add, r13, sp, o));
  ins st (ISA.Store (ISA.W, r13, lr, 0))

let try_exit st k =
  at st k 12 (fun o -> ISA.Load (ISA.W, r13, sp, o));
  emit st (Asm.La (lr, "ml_handler"));
  ins st (ISA.Store (ISA.W, r13, lr, 0))

let instruction (st : state) (i : ir) =
  match i with
  | Label l ->
      (match Hashtbl.find_opt st.mdepth_at l with
       | Some d when st.mdead -> st.msp <- d
       | _ -> ());
      st.mdead <- false;
      emit st (Asm.Label (lab l))
  | Catch k ->
      st.mdead <- false;
      st.msp <- Hashtbl.find st.mcatch_at k;
      reload st;
      result st
  | _ when st.mdead -> ()
  (* old: Int64.to_int32 v alone: 4611686018427387903 became -1, and
   * the program printed something else than OCaml *)
  | Imm v ->
      if low32 v <> v then
        Lexer.error
          "an integer beyond 31 bits: not on TinyCPU (a 32-bit machine)";
      emit st (Asm.Li (push st, v))
  | Addr s -> emit st (Asm.La (push st, s))
  | Get i -> get st i (push st)
  | Set i -> put st st.msp i; pop st
  | GetG (t, g) ->
      let r = push st in
      emit st (Asm.La (r, t));
      ins st (ISA.Load (ISA.W, r, r, 4 * g))
  | SetG (t, g) ->
      emit st (Asm.La (r13, t));
      ins st (ISA.Store (ISA.W, st.msp, r13, 4 * g));
      pop st
  | Field k -> ins st (ISA.Load (ISA.W, st.msp, st.msp, 4 * k))
  | SetField k ->
      ins st (ISA.Store (ISA.W, st.msp - 1, st.msp, 4 * k));
      st.msp <- st.msp - 2
  | Alloc (tag, n) ->
      alloc st tag n;
      for k = 0 to n - 1 do
        get st (spill_slot st (st.msp - k)) lr;
        ins st (ISA.Store (ISA.W, lr, r13, 4 * k))
      done;
      st.msp <- st.msp - n;
      reload st;
      result st
  | Blank (tag, n) ->
      alloc st tag n;
      emit st (Asm.Li (lr, Int64.one));
      for k = 0 to n - 1 do
        ins st (ISA.Store (ISA.W, lr, r13, 4 * k))
      done;
      reload st;
      result st
  | Op o -> op st o
  | Call (t, n, tail) -> call st t n tail
  | CallC ("ml_string_length", 1) -> string_length st
  | CallC ("ml_string_get", 2) -> string_get st
  | CallC (f, n) -> call_c st f n
  | Jmp l -> jump st l; emit st (Asm.Jump (lab l)); st.mdead <- true
  | Jz l -> branch st ISA.Eq l
  | Jnz l -> branch st ISA.Ne l
  | Drop -> pop st
  | Ret ->
      emit st (Asm.Mov (r13, st.msp));
      pop st; epilogue st; emit st Asm.Ret; st.mdead <- true
  | Raise ->
      emit st (Asm.Mov (r13, st.msp));
      emit st (Asm.La (lr, "ml_raise"));
      ins st (ISA.Jalr (0, lr, 0));
      st.mdead <- true
  | TryEnter (k, handler) -> try_enter st k handler
  | TryExit k -> try_exit st k

(* [machine f nparams nslots code]: f's assembly *)
let machine (name : sym) nparams nslots (code : ir list) : Asm.line list =
  let st =
    { mname = name; mslots = nslots; mlines = [];
      msp = 0; mmaxsp = 0; mtries = 0; mcargs = 0; mdead = false;
      mdepth_at = Hashtbl.create 16; mcatch_at = Hashtbl.create 4 } in
  List.iter (instruction st) code;
  if nparams > 10 then
    Lexer.error
      (name ^ ": " ^ string_of_int nparams
       ^ " parameters (tiny-machine passes 10 at most)");
  let f = nslots + st.mmaxsp and c = 4 * st.mcargs in
  let m = (record c st.mtries + 7) land lnot 7 in
  let store r i = Asm.Instr (ISA.Store (ISA.W, r, vsp, 4 * (i - f))) in
  (* a piece: tiny-linker leaves it out when nothing names its labels;
   * the frames made, the closure and the parameters in their slots *)
  [ Asm.Piece; Asm.Label name;
    Asm.Instr (ISA.Alui (ISA.Add, sp, sp, - m));
    Asm.Instr (ISA.Store (ISA.W, lr, sp, c));
    Asm.Instr (ISA.Alui (ISA.Add, vsp, vsp, 4 * f));
    store r13 0 ]
  @ List.init nparams (fun i -> store (i + 1) (i + 1))
  (* the other slots zeroed: the collector scans them *)
  @ List.init (max 0 (f - 1 - nparams)) (fun k -> store 0 (nparams + 1 + k))
  @ List.rev_map (fun l -> match l with Known l -> l | Framed g -> g f m c)
      st.mlines

(* ml_start called by C (the value stack's base at 0(sp)), ml_init's
 * closure slot 1, a unit (not what r13 held, which the collector would
 * scan); ml_raise: to the latest handler, the exception in r13 *)
let start =
  let ldw d a off = Asm.Instr (ISA.Load (ISA.W, d, a, off)) in
  String.concat ""
    (List.map Asm.print
       [ Asm.Label "ml_start"; ldw vsp sp 0; Asm.Li (r13, Int64.one);
         Asm.La (r11, "ml_init"); Asm.Instr (ISA.Jalr (0, r11, 0));
         Asm.Label "ml_raise"; Asm.La (1, "ml_handler"); ldw 1 1 0;
         ldw sp 1 0; ldw vsp 1 4; ldw 2 1 12; Asm.La (3, "ml_handler");
         Asm.Instr (ISA.Store (ISA.W, 2, 3, 0)); ldw 2 1 8;
         Asm.Instr (ISA.Jalr (0, 2, 0)) ])

(*****************************************************************************)
(* Data: static blocks *)
(*****************************************************************************)

(* a word of data: a number, a function's code, or a static block's
 * value (its first field's address) *)
type dword = DNum of int64 | DCode of sym | DVal of sym

let fields sym ws =
  Asm.Label sym
  :: List.map (fun w ->
       match w with
       | DNum x -> Asm.Word x
       | DCode x -> Asm.Word_sym x
       | DVal x -> Asm.Word_sym x) ws
(* each a piece of its own, as a function is *)
let words sym ws = add_data (Asm.Piece :: fields sym ws)

(* a static block, its header then its fields. Its symbol is the first
 * field's, the value itself (the assembler's expressions have no
 * sym+n) *)
let block sym hdr ws = add_data (Asm.Piece :: Asm.Word hdr :: fields sym ws)

let header n tag = Int64.of_int ((n lsl 10) lor tag)
let closure_tag = 247 and string_tag = 252

(* a string: its words, the last byte the number of the others that are
 * padding, as OCaml's *)
let strings = Hashtbl.create 16
let static_string s =
  match Hashtbl.find_opt strings s with
  | Some sym -> sym
  | None ->
      let sym = !Tree.unit_name ^ ".s"
        ^ string_of_int (Hashtbl.length strings) in
      let n = (String.length s / 4) + 1 in
      let b = Bytes.make (4 * n) '\000' in
      Bytes.blit_string s 0 b 0 (String.length s);
      Bytes.set b ((4 * n) - 1) (Char.chr ((4 * n) - 1 - String.length s));
      block sym (header n string_tag)
        (List.init n (fun i ->
           let byte k = Char.code (Bytes.get b ((4 * i) + k)) in
           (* (old: Int32.to_string of Bytes.get_int32_le) *)
           DNum
             (low32
                (Int64.logor (Int64.shift_left (Int64.of_int (byte 3)) 24)
                   (Int64.of_int
                      (byte 0 lor (byte 1 lsl 8) lor (byte 2 lsl 16)))))));
      Hashtbl.replace strings s sym;
      sym

(* the curry functions an arity needs (the program's, its main's to
 * make: each unit says the arities it needs) *)
let arities = ref []
let curry n k = Printf.sprintf "ml_curry%d_%d" n k
let entry n lab =
  if n = 1 then lab
  else (
    if not (List.mem n !arities) then arities := n :: !arities;
    curry n 0)
let closure_sym lab = lab ^ ".c"
let static_closure lab n =
  let sym = closure_sym lab in
  block sym (header 2 closure_tag) [ DCode (entry n lab); DCode lab ];
  sym

(* an exception: a block with its name, compared by address; its value
 * a block [the exception; its arguments], a static one without them *)
let exn_id c = "ml_exn_" ^ Tree.con_base c
let exn_const c = "ml_exv_" ^ Tree.con_base c

(* (old: 2L, 1L, literals tiny-ml does not read) *)
let tagged n = Int64.add (Int64.mul (Int64.of_int 2) (Int64.of_int n)) Int64.one
