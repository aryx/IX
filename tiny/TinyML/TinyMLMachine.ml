(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMLMachine.mli *)
open TinyMLLexer
open TinyMLTree

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
  | Catch of int                      (* the handler's entry: the exception pushed *)

let labels = ref 0
let label () : label = incr labels; !labels
let text = Buffer.create 65536 and data = Buffer.create 16384

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

(* A function's code as it is made. Its lines: the text, and those that
 * the frame's sizes make (f, m, c, known at the end) as functions of
 * them; the text between two of those in one buffer (old: a function a
 * line, every line's string made at the end). The stack machine's
 * depth (its top register) and the deepest; the handlers and the words
 * of C's arguments, the most of a call; dead after a jump, until a
 * label; the depth at each label jumped to, and at each handler.
 * (old: refs local to machine, its 320 lines a closure each) *)
type state = {
  mname : sym;
  mslots : int;
  mutable mlines : (int -> int -> int -> string) list;
  mchunk : Buffer.t;
  mutable msp : int;
  mutable mmaxsp : int;
  mutable mtries : int;
  mutable mcargs : int;
  mutable mdead : bool;
  mdepth_at : (label, int) Hashtbl.t;
  mcatch_at : (int, int) Hashtbl.t;
}

let flush (st : state) =
  if Buffer.length st.mchunk > 0 then (
    let s = Buffer.contents st.mchunk in
    Buffer.clear st.mchunk;
    st.mlines <- (fun _ _ _ -> s) :: st.mlines)
let line (st : state) f = flush st; st.mlines <- f :: st.mlines
let ins (st : state) s =
  Buffer.add_char st.mchunk '\t'; Buffer.add_string st.mchunk s;
  Buffer.add_char st.mchunk '\n'

(* a slot to a register, and back, at r12, the frame's top *)
let get st (i : slot) r =
  line st (fun f _ _ -> Printf.sprintf "\tldw\tr%d, %d(r12)\n" r (4 * (i - f)))
let put st r (i : slot) =
  line st (fun f _ _ -> Printf.sprintf "\tstw\tr%d, %d(r12)\n" r (4 * (i - f)))
(* where a register is spilled *)
let spill_slot (st : state) r : slot = st.mslots + r - 1
let push (st : state) =
  st.msp <- st.msp + 1;
  if st.msp > 11 then
    error
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
let result st = ins st (Printf.sprintf "mov\tr%d, r13" (push st))
let lab (l : label) = !unit_name ^ ".L" ^ string_of_int l
let jump (st : state) l = Hashtbl.replace st.mdepth_at l st.msp
let epilogue st =
  line st (fun f _ _ -> Printf.sprintf "\taddi\tr12, r12, %d\n" (-4 * f));
  line st (fun _ _ c -> Printf.sprintf "\tldw\tlr, %d(sp)\n" c);
  line st (fun _ m _ -> Printf.sprintf "\taddi\tsp, sp, %d\n" m)
(* the k-th handler's record on the machine stack, above the link *)
let record c k = c + 4 + (16 * k)
let at st k d f = line st (fun _ _ c -> "\t" ^ f (record c k + d) ^ "\n")
let c_call st f =
  ins st "la\tlr, ml_vsp"; ins st "stw\tr12, 0(lr)";
  ins st ("la\tlr, " ^ f); ins st "jalr\tlr, 0(lr)";
  ins st "la\tlr, ml_vsp"; ins st "ldw\tr12, 0(lr)"
(* a binary operation's registers, the result in the second *)
let bin (st : state) f = let a = st.msp in pop st; f a st.msp
(* the integer in register d tagged *)
let tag_int st d =
  ins st (Printf.sprintf "shli\tr%d, r%d, 1" d d);
  ins st (Printf.sprintf "ori\tr%d, r%d, 1" d d)

let op (st : state) o =
  let ins = ins st and bin = bin st and tagged = tag_int st in
  let a = st.msp in
  match o with
  | Add ->
      bin (fun a b ->
        ins (Printf.sprintf "add\tr%d, r%d, r%d" b a b);
        ins (Printf.sprintf "addi\tr%d, r%d, -1" b b))
  | Sub ->
      bin (fun a b ->
        ins (Printf.sprintf "sub\tr%d, r%d, r%d" b a b);
        ins (Printf.sprintf "addi\tr%d, r%d, 1" b b))
  | Mul ->
      bin (fun a b ->
        ins (Printf.sprintf "addi\tr%d, r%d, -1" a a);
        ins (Printf.sprintf "sari\tr%d, r%d, 1" b b);
        ins (Printf.sprintf "mul\tr%d, r%d, r%d" b a b);
        ins (Printf.sprintf "addi\tr%d, r%d, 1" b b))
  | Div | Mod ->
      bin (fun a b ->
        ins (Printf.sprintf "sari\tr%d, r%d, 1" a a);
        ins (Printf.sprintf "sari\tr%d, r%d, 1" b b);
        ins ((if o = Div then "div" else "rem") ^ "\tr" ^ string_of_int b
             ^ ", r" ^ string_of_int a ^ ", r" ^ string_of_int b);
        tagged b)
  | And -> bin (fun a b -> ins (Printf.sprintf "and\tr%d, r%d, r%d" b a b))
  | Or -> bin (fun a b -> ins (Printf.sprintf "or\tr%d, r%d, r%d" b a b))
  | Xor ->
      bin (fun a b ->
        ins (Printf.sprintf "xor\tr%d, r%d, r%d" b a b);
        ins (Printf.sprintf "ori\tr%d, r%d, 1" b b))
  | Lsl ->
      bin (fun a b ->
        ins (Printf.sprintf "addi\tr%d, r%d, -1" a a);
        ins (Printf.sprintf "sari\tr%d, r%d, 1" b b);
        ins (Printf.sprintf "shl\tr%d, r%d, r%d" b a b);
        ins (Printf.sprintf "ori\tr%d, r%d, 1" b b))
  | Lsr | Asr ->
      bin (fun a b ->
        ins (Printf.sprintf "sari\tr%d, r%d, 1" b b);
        ins ((if o = Lsr then "shr" else "sar") ^ "\tr" ^ string_of_int b
             ^ ", r" ^ string_of_int a ^ ", r" ^ string_of_int b);
        ins (Printf.sprintf "ori\tr%d, r%d, 1" b b))
  | Cmp r ->
      (* a r b, 1 or 0, then tagged *)
      bin (fun a b ->
        (match r with
         | Lt -> ins (Printf.sprintf "slt\tr%d, r%d, r%d" b a b)
         | Gt -> ins (Printf.sprintf "slt\tr%d, r%d, r%d" b b a)
         | Le ->
             ins (Printf.sprintf "slt\tr%d, r%d, r%d" b b a);
             ins (Printf.sprintf "xori\tr%d, r%d, 1" b b)
         | Ge ->
             ins (Printf.sprintf "slt\tr%d, r%d, r%d" b a b);
             ins (Printf.sprintf "xori\tr%d, r%d, 1" b b)
         | Eq ->
             ins (Printf.sprintf "sub\tr%d, r%d, r%d" b a b);
             ins (Printf.sprintf "sltiu\tr%d, r%d, 1" b b)
         | Ne ->
             ins (Printf.sprintf "sub\tr%d, r%d, r%d" b a b);
             ins (Printf.sprintf "sltu\tr%d, zero, r%d" b b));
        tagged b)
  | Neg ->
      ins (Printf.sprintf "sub\tr%d, zero, r%d" a a);
      ins (Printf.sprintf "addi\tr%d, r%d, 2" a a)
  | Lnot ->
      ins "addi\tr13, zero, -1";
      ins (Printf.sprintf "xor\tr%d, r%d, r13" a a);
      ins (Printf.sprintf "ori\tr%d, r%d, 1" a a)
  | Not -> ins (Printf.sprintf "xori\tr%d, r%d, 2" a a)
  | IsInt -> ins (Printf.sprintf "andi\tr%d, r%d, 1" a a); tagged a
  | Tag -> ins (Printf.sprintf "ldb\tr%d, -4(r%d)" a a); tagged a

(* a block of n fields from the runtime, in r13 *)
let alloc (st : state) tag n =
  spill st;
  st.mcargs <- max st.mcargs 2;
  ins st (Printf.sprintf "li\tr13, %d" n); ins st "stw\tr13, 0(sp)";
  ins st (Printf.sprintf "li\tr13, %d" tag); ins st "stw\tr13, 4(sp)";
  c_call st "ml_alloc"

(* a call of ML: the closure in r13, the arguments in r1..rn *)
let call (st : state) t n tail =
  if n > 10 then
    error
      (st.mname ^ ": " ^ string_of_int n
       ^ " arguments (tiny-machine passes 10 at most)");
  spill st;
  get st (spill_slot st st.msp) 13;
  for k = 1 to n do get st (spill_slot st (st.msp - k)) k done;
  st.msp <- st.msp - n - 1;
  if tail then begin
    epilogue st;
    (match t with
     | Direct f -> ins st ("la\tr11, " ^ f)
     | Indirect k -> ins st (Printf.sprintf "ldw\tr11, %d(r13)" (4 * k)));
    ins st "jalr\tzero, 0(r11)";
    st.mdead <- true
  end
  else begin
    (match t with
     | Direct f -> ins st ("la\tlr, " ^ f)
     | Indirect k -> ins st (Printf.sprintf "ldw\tlr, %d(r13)" (4 * k)));
    ins st "jalr\tlr, 0(lr)";
    reload st;
    result st
  end

(* a call of C, the runtime's: the arguments in memory *)
let call_c (st : state) f n =
  spill st;
  st.mcargs <- max st.mcargs n;
  for k = 0 to n - 1 do
    get st (spill_slot st (st.msp - k)) 13;
    ins st (Printf.sprintf "stw\tr13, %d(sp)" (4 * k))
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
  ins st (Printf.sprintf "ldw\tr13, -4(r%d)" s);
  ins st "shri\tr13, r13, 10";
  ins st "shli\tr13, r13, 2";
  ins st (Printf.sprintf "add\tlr, r%d, r13" s);
  ins st "ldb\tlr, -1(lr)";
  ins st "sub\tr13, r13, lr";
  ins st "addi\tr13, r13, -1"

let string_length (st : state) =
  length_of st st.msp;
  ins st (Printf.sprintf "mov\tr%d, r13" st.msp);
  tag_int st st.msp

(* s.[i]: s is on top of the stack, i below it, and the byte takes i's
 * register. The index is checked against the length; only an index out
 * of bounds calls ml_string_get, which reports the error. *)
let string_get (st : state) =
  let s = st.msp and i = st.msp - 1 in
  let slow = label () and done_ = label () in
  length_of st s;
  ins st (Printf.sprintf "sari\tlr, r%d, 1" i);
  ins st ("bgeu\tlr, r13, " ^ lab slow);
  ins st (Printf.sprintf "add\tlr, r%d, lr" s);
  ins st (Printf.sprintf "ldb\tr%d, 0(lr)" i);
  tag_int st i;
  ins st ("j\t" ^ lab done_);
  line st (fun _ _ _ -> lab slow ^ ":\n");
  call_c st "ml_string_get" 2;
  line st (fun _ _ _ -> lab done_ ^ ":\n")

(* a jump if the top is false (beq), or true (bne) *)
let branch (st : state) b l =
  let r = st.msp in
  pop st; jump st l; ins st "li\tr13, 1";
  ins st (Printf.sprintf "%s\tr%d, r13, %s" b r (lab l))

(* the handler's record: sp, r12, the handler's address (call's link:
 * the j after it), the previous record *)
let try_enter (st : state) k handler =
  spill st;
  Hashtbl.replace st.mcatch_at k st.msp;
  st.mtries <- max st.mtries (k + 1);
  let set = label () in
  ins st ("call\t" ^ lab set);
  ins st ("j\t" ^ lab handler);
  line st (fun _ _ _ -> lab set ^ ":\n");
  at st k 0 (fun o -> Printf.sprintf "stw\tsp, %d(sp)" o);
  at st k 4 (fun o -> Printf.sprintf "stw\tr12, %d(sp)" o);
  at st k 8 (fun o -> Printf.sprintf "stw\tlr, %d(sp)" o);
  ins st "la\tlr, ml_handler";
  ins st "ldw\tr13, 0(lr)";
  at st k 12 (fun o -> Printf.sprintf "stw\tr13, %d(sp)" o);
  at st k 0 (fun o -> Printf.sprintf "addi\tr13, sp, %d" o);
  ins st "stw\tr13, 0(lr)"

let try_exit st k =
  at st k 12 (fun o -> Printf.sprintf "ldw\tr13, %d(sp)" o);
  ins st "la\tlr, ml_handler"; ins st "stw\tr13, 0(lr)"

let instruction (st : state) (i : ir) =
  let ins = ins st in
  match i with
  | Label l ->
      (match Hashtbl.find_opt st.mdepth_at l with
       | Some d when st.mdead -> st.msp <- d
       | _ -> ());
      st.mdead <- false;
      line st (fun _ _ _ -> lab l ^ ":\n")
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
        error "an integer beyond 31 bits: not on TinyCPU (a 32-bit machine)";
      ins ("li\tr" ^ string_of_int (push st) ^ ", " ^ Int64.to_string v)
  | Addr s -> ins (Printf.sprintf "la\tr%d, %s" (push st) s)
  | Get i -> get st i (push st)
  | Set i -> put st st.msp i; pop st
  | GetG (t, g) ->
      let r = push st in
      ins (Printf.sprintf "la\tr%d, %s" r t);
      ins (Printf.sprintf "ldw\tr%d, %d(r%d)" r (4 * g) r)
  | SetG (t, g) ->
      ins ("la\tr13, " ^ t);
      ins (Printf.sprintf "stw\tr%d, %d(r13)" st.msp (4 * g));
      pop st
  | Field k -> ins (Printf.sprintf "ldw\tr%d, %d(r%d)" st.msp (4 * k) st.msp)
  | SetField k ->
      ins (Printf.sprintf "stw\tr%d, %d(r%d)" (st.msp - 1) (4 * k) st.msp);
      st.msp <- st.msp - 2
  | Alloc (tag, n) ->
      alloc st tag n;
      for k = 0 to n - 1 do
        get st (spill_slot st (st.msp - k)) 15;
        ins (Printf.sprintf "stw\tr15, %d(r13)" (4 * k))
      done;
      st.msp <- st.msp - n;
      reload st;
      result st
  | Blank (tag, n) ->
      alloc st tag n;
      ins "li\tr15, 1";
      for k = 0 to n - 1 do
        ins (Printf.sprintf "stw\tr15, %d(r13)" (4 * k))
      done;
      reload st;
      result st
  | Op o -> op st o
  | Call (t, n, tail) -> call st t n tail
  | CallC ("ml_string_length", 1) -> string_length st
  | CallC ("ml_string_get", 2) -> string_get st
  | CallC (f, n) -> call_c st f n
  | Jmp l -> jump st l; ins ("j\t" ^ lab l); st.mdead <- true
  | Jz l -> branch st "beq" l
  | Jnz l -> branch st "bne" l
  | Drop -> pop st
  | Ret ->
      ins (Printf.sprintf "mov\tr13, r%d" st.msp);
      pop st; epilogue st; ins "ret"; st.mdead <- true
  | Raise ->
      ins (Printf.sprintf "mov\tr13, r%d" st.msp);
      ins "la\tlr, ml_raise"; ins "jalr\tzero, 0(lr)"; st.mdead <- true
  | TryEnter (k, handler) -> try_enter st k handler
  | TryExit k -> try_exit st k

(* [machine f nparams nslots code]: f's assembly, in text *)
let machine (name : sym) nparams nslots (code : ir list) =
  let st =
    { mname = name; mslots = nslots; mlines = []; mchunk = Buffer.create 256;
      msp = 0; mmaxsp = 0; mtries = 0; mcargs = 0; mdead = false;
      mdepth_at = Hashtbl.create 16; mcatch_at = Hashtbl.create 4 } in
  List.iter (instruction st) code;
  if nparams > 10 then
    error
      (name ^ ": " ^ string_of_int nparams
       ^ " parameters (tiny-machine passes 10 at most)");
  let f = nslots + st.mmaxsp and c = 4 * st.mcargs in
  let m = (record c st.mtries + 7) land lnot 7 in
  let out s = Buffer.add_string text s in
  (* a piece: tiny-linker leaves it out when nothing names its labels *)
  out "\t.piece\n";
  out (name ^ ":\n\taddi\tsp, sp, " ^ string_of_int (- m) ^ "\n\tstw\tlr, "
       ^ string_of_int c ^ "(sp)\n\taddi\tr12, r12, " ^ string_of_int (4 * f)
       ^ "\n");
  out (Printf.sprintf "\tstw\tr13, %d(r12)\n" (-4 * f));
  for i = 1 to nparams do
    out (Printf.sprintf "\tstw\tr%d, %d(r12)\n" i (4 * (i - f)))
  done;
  (* the other slots zeroed: the collector scans them *)
  for i = nparams + 1 to f - 1 do
    out (Printf.sprintf "\tstw\tzero, %d(r12)\n" (4 * (i - f)))
  done;
  flush st;
  List.iter (fun l -> Buffer.add_string text (l f m c)) (List.rev st.mlines)

(* ml_start called by C (the value stack's base at 0(sp)), ml_init's
 * closure slot 1, a unit (not what r13 held, which the collector would
 * scan); ml_raise: to the latest handler, the exception in r13 *)
let start =
  String.concat "\n\t"
    [ "ml_start:"; "ldw\tr12, 0(sp)"; "li\tr13, 1"; "la\tr11, ml_init";
      "jalr\tzero, 0(r11)";
      "ml_raise:\n\tla\tr1, ml_handler"; "ldw\tr1, 0(r1)"; "ldw\tsp, 0(r1)";
      "ldw\tr12, 4(r1)"; "ldw\tr2, 12(r1)"; "la\tr3, ml_handler";
      "stw\tr2, 0(r3)"; "ldw\tr2, 8(r1)"; "jalr\tzero, 0(r2)" ]
  ^ "\n"

(*****************************************************************************)
(* Data: static blocks *)
(*****************************************************************************)

(* a word of data: a number, a function's code, or a static block's
 * value (its first field's address) *)
type dword = DNum of string | DCode of sym | DVal of sym

(* each a piece of its own, as a function is *)
let fields sym ws =
  Buffer.add_string data (sym ^ ":\n");
  List.iter (fun w ->
      Printf.bprintf data "\t.word\t%s\n"
        (match w with DNum x -> x | DCode x -> x | DVal x -> x))
    ws
let words sym ws = Buffer.add_string data "\t.piece\n"; fields sym ws

(* a static block, its header then its fields. Its symbol is the first
 * field's, the value itself (the assembler's expressions have no
 * sym+n) *)
let block sym hdr ws =
  Printf.bprintf data "\t.piece\n\t.word\t%s\n" hdr; fields sym ws

let header n tag = string_of_int ((n lsl 10) lor tag)
let closure_tag = 247 and string_tag = 252

(* a string: its words, the last byte the number of the others that are
 * padding, as OCaml's *)
let strings = Hashtbl.create 16
let static_string s =
  match Hashtbl.find_opt strings s with
  | Some sym -> sym
  | None ->
      let sym = (!unit_name ^ ".s" ^ string_of_int (Hashtbl.length strings)) in
      let n = (String.length s / 4) + 1 in
      let b = Bytes.make (4 * n) '\000' in
      Bytes.blit_string s 0 b 0 (String.length s);
      Bytes.set b ((4 * n) - 1) (Char.chr ((4 * n) - 1 - String.length s));
      block sym (header n string_tag)
        (List.init n (fun i ->
           let byte k = Char.code (Bytes.get b ((4 * i) + k)) in
           (* (old: Int32.to_string of Bytes.get_int32_le) *)
           DNum
             (Int64.to_string
                (low32
                   (Int64.logor (Int64.shift_left (Int64.of_int (byte 3)) 24)
                      (Int64.of_int
                         (byte 0 lor (byte 1 lsl 8) lor (byte 2 lsl 16))))))));
      Hashtbl.replace strings s sym;
      sym

(* the curry functions an arity needs (the program's, its main's to
 * make: each unit says the arities it needs) *)
let arities = ref []
let curry n k = (Printf.sprintf "ml_curry%d_%d" n k)
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
let exn_id c = "ml_exn_" ^ con_base c
let exn_const c = "ml_exv_" ^ con_base c

(* (old: 2L, 1L, literals tiny-ml does not read) *)
let tagged n = Int64.add (Int64.mul (Int64.of_int 2) (Int64.of_int n)) Int64.one
