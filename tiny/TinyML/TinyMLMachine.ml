(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMLMachine.mli *)
open TinyMLLexer
open TinyMLTree

(* the machine, tiny-machine, has words of 4 bytes: an integer 31 bits
 * (a constant beyond them is refused), a block's fields 4 bytes each *)

(*****************************************************************************)
(* The stack machine *)
(*****************************************************************************)

type rel = Eq | Ne | Lt | Le | Gt | Ge
type op =
  | Add | Sub | Mul | Div | Mod | And | Or | Xor | Lsl | Lsr | Asr | Cmp of rel
  | Neg | Lnot | Not | IsInt | Tag
(* a function's n-ary code, or a closure's field *)
type target = Direct of string | Code of int

(* a binary operation's first operand is on top, as every operation's:
 * arguments are pushed from the last, as OCaml evaluates them *)
(* a word's 32 bits, signed: what the machine keeps of an int64 *)
let low32 v = Int64.shift_right (Int64.shift_left v 32) 32

type ir =
  | Imm of int64                      (* a word, an integer already tagged *)
  | Addr of string * int              (* a symbol's address: a static block's
                                       * value is its +8 *)
  | Get of int | Set of int           (* a slot of the function's frame on the
                                       * value stack *)
  | GetG of string * int | SetG of string * int   (* a global of a unit: its
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
  | CallC of string * int             (* a runtime's function of n arguments *)
  | Label of int | Jmp of int
  | Jz of int | Jnz of int            (* false is 1, the tagged 0 *)
  | Drop
  | Ret
  | Raise                             (* the top raised; its place taken by the
                                       * result, never seen *)
  | TryEnter of int * int             (* the k-th handler of the function, its
                                       * code *)
  | TryExit of int
  | Catch of int                      (* the handler's entry: the exception pushed *)

let labels = ref 0
let label () = incr labels; !labels
let text = Buffer.create 65536 and data = Buffer.create 16384

(*****************************************************************************)
(* The machine: tiny-machine, the stack in r1..r11, the value stack at r12 *)
(*****************************************************************************)

(* TinyMachineCPU's CPU: 32-bit registers, r0 zero, no flags, sp r14, lr
 * r15. The stack machine's registers are r1..r11 (an expression 11
 * deep at most), the value stack's top is r12, r13 the scratch and the
 * result. A function's frames, in words of 4 bytes. On the value
 * stack, f words below r12 (its top, which the function raises by f at
 * its entry): slot 0 its closure, then its parameters, its variables,
 * and a slot per register of the stack machine, where a call or an
 * allocation spills it. On the machine stack, m bytes: C's outgoing
 * arguments from 0(sp) (tiny-c's convention:
 * every argument in memory, the result in r13, every register but sp
 * the callee's), the link at c, then 16 bytes per handler. A call of
 * ML passes the closure in r13 and the arguments in r1..rn (r0 is the
 * zero), so at most 10 (r11 is a tail call's target); the result is in
 * r13. Every call is la then jalr: a jal reaches only 128 KB, and a
 * kernel with its runtime and its programs is bigger. After a call of
 * C, r12 comes back from ml_vsp (C keeps no register). *)
let machine name nparams nslots (code : ir list) =
  (* the lines: text, and those that the frame's sizes make (f, m, c,
   * known at the end) as functions of them; the text between two of
   * those in one buffer (old: a function a line, every line's string
   * made at the end) *)
  let lines = ref [] and chunk = Buffer.create 256 in
  let flush () =
    if Buffer.length chunk > 0 then (
      let s = Buffer.contents chunk in
      Buffer.clear chunk;
      lines := (fun _ _ _ -> s) :: !lines)
  in
  let line f = flush (); lines := f :: !lines in
  let ins s =
    Buffer.add_char chunk '\t'; Buffer.add_string chunk s;
    Buffer.add_char chunk '\n' in
  let sp = ref 0 and maxsp = ref 0 and tries = ref 0 and cargs = ref 0
  and dead = ref false in
  let depth_at = Hashtbl.create 16 and catch_at = Hashtbl.create 4 in
  let get i r =
    line (fun f _ _ -> (Printf.sprintf "\tldw\tr%d, %d(r12)\n" r (4 * (i - f))))
  in
  let put r i =
    line (fun f _ _ -> (Printf.sprintf "\tstw\tr%d, %d(r12)\n" r (4 * (i - f))))
  in
  let spill_slot r = nslots + r - 1 in
  let push () =
    incr sp;
    if !sp > 11 then
      error
        (name
         ^ ": an expression too deep (tiny-machine has 11 registers for it)");
    maxsp := max !maxsp !sp;
    !sp
  in
  let spill () = for r = 1 to !sp do put r (spill_slot r) done in
  let reload () = for r = 1 to !sp do get (spill_slot r) r done in
  let result () = ins (Printf.sprintf "mov\tr%d, r13" (push ())) in
  let lab l = (!unit_name ^ ".L" ^ string_of_int l) in
  let jump l = Hashtbl.replace depth_at l !sp in
  let epilogue () =
    line (fun f _ _ -> (Printf.sprintf "\taddi\tr12, r12, %d\n" (-4 * f)));
    line (fun _ _ c -> (Printf.sprintf "\tldw\tlr, %d(sp)\n" c));
    line (fun _ m _ -> (Printf.sprintf "\taddi\tsp, sp, %d\n" m))
  in
  let record c k = c + 4 + (16 * k) in
  let at k d f = line (fun _ _ c -> "\t" ^ f (record c k + d) ^ "\n") in
  let c_call f =
    ins "la\tlr, ml_vsp"; ins "stw\tr12, 0(lr)";
    ins ("la\tlr, " ^ f); ins "jalr\tlr, 0(lr)";
    ins "la\tlr, ml_vsp"; ins "ldw\tr12, 0(lr)"
  in
  let bin f = let a = !sp in decr sp; f a !sp in
  let tagged d =
    ins (Printf.sprintf "shli\tr%d, r%d, 1" d d);
    ins (Printf.sprintf "ori\tr%d, r%d, 1" d d) in
  (* the length of the string in register s, untagged, into r13; lr used *)
  let length_of s =
    ins (Printf.sprintf "ldw\tr13, -4(r%d)" s);
    ins "shri\tr13, r13, 10";
    ins "shli\tr13, r13, 2";
    ins (Printf.sprintf "add\tlr, r%d, r13" s);
    ins "ldb\tlr, -1(lr)";
    ins "sub\tr13, r13, lr";
    ins "addi\tr13, r13, -1" in
  let op o =
    let a = !sp in
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
  in
  (* a block of n fields from the runtime, in r13 *)
  let alloc tag n =
    spill ();
    cargs := max !cargs 2;
    ins (Printf.sprintf "li\tr13, %d" n); ins "stw\tr13, 0(sp)";
    ins (Printf.sprintf "li\tr13, %d" tag); ins "stw\tr13, 4(sp)";
    c_call "ml_alloc" in
  List.iter (fun i ->
    match i with
    | Label l ->
        (match Hashtbl.find_opt depth_at l with
         | Some d when !dead -> sp := d
         | _ -> ());
        dead := false;
        line (fun _ _ _ -> lab l ^ ":\n")
    | Catch k -> dead := false; sp := Hashtbl.find catch_at k; reload (); result ()
    | _ when !dead -> ()
    (* old: Int64.to_int32 v alone: 4611686018427387903 became -1, and
     * the program printed something else than OCaml *)
    | Imm v ->
        if low32 v <> v then
          error "an integer beyond 31 bits: not on TinyCPU (a 32-bit machine)";
        ins ("li\tr" ^ string_of_int (push ()) ^ ", " ^ Int64.to_string v)
    | Addr (s, _) -> ins (Printf.sprintf "la\tr%d, %s" (push ()) s)
    | Get i -> get i (push ())
    | Set i -> put !sp i; decr sp
    | GetG (t, g) ->
        let r = push () in
        ins (Printf.sprintf "la\tr%d, %s" r t);
        ins (Printf.sprintf "ldw\tr%d, %d(r%d)" r (4 * g) r)
    | SetG (t, g) ->
        ins ("la\tr13, " ^ t);
        ins (Printf.sprintf "stw\tr%d, %d(r13)" !sp (4 * g));
        decr sp
    | Field k -> ins (Printf.sprintf "ldw\tr%d, %d(r%d)" !sp (4 * k) !sp)
    | SetField k ->
        ins (Printf.sprintf "stw\tr%d, %d(r%d)" (!sp - 1) (4 * k) !sp);
        sp := !sp - 2
    | Alloc (tag, n) ->
        alloc tag n;
        for k = 0 to n - 1 do
          get (spill_slot (!sp - k)) 15;
          ins (Printf.sprintf "stw\tr15, %d(r13)" (4 * k))
        done;
        sp := !sp - n;
        reload ();
        result ()
    | Blank (tag, n) ->
        alloc tag n;
        ins "li\tr15, 1";
        for k = 0 to n - 1 do
          ins (Printf.sprintf "stw\tr15, %d(r13)" (4 * k))
        done;
        reload ();
        result ()
    | Op o -> op o
    | Call (t, n, tail) ->
        if n > 10 then
          error
            (name ^ ": " ^ string_of_int n
             ^ " arguments (tiny-machine passes 10 at most)");
        spill ();
        get (spill_slot !sp) 13;
        for k = 1 to n do get (spill_slot (!sp - k)) k done;
        sp := !sp - n - 1;
        if tail then begin
          epilogue ();
          (match t with
           | Direct f -> ins ("la\tr11, " ^ f)
           | Code k -> ins (Printf.sprintf "ldw\tr11, %d(r13)" (4 * k)));
          ins "jalr\tzero, 0(r11)";
          dead := true
        end
        else begin
          (match t with
           | Direct f -> ins ("la\tlr, " ^ f)
           | Code k -> ins (Printf.sprintf "ldw\tlr, %d(r13)" (4 * k)));
          ins "jalr\tlr, 0(lr)";
          reload ();
          result ()
        end
    (* A string's length and its bytes are read inline rather than by a
     * call of the runtime: a call for each byte was a quarter of the time
     * a browser took to read a page (plan_tiny_browser.md, section 12).
     * The length comes from the block's header and its last byte, as in
     * TinyMLRuntime/core.c's length. Only r13 and lr are free here (lr
     * is saved by the prologue). *)
    | CallC ("ml_string_length", 1) ->
        length_of !sp;
        ins (Printf.sprintf "mov\tr%d, r13" !sp);
        tagged !sp
    (* s.[i]: s is on top of the stack, i below it, and the byte takes
     * i's register. The index is checked against the length; only an
     * index out of bounds calls ml_string_get, which reports the error. *)
    | CallC ("ml_string_get", 2) ->
        let s = !sp and i = !sp - 1 in
        let slow = label () and done_ = label () in
        length_of s;
        ins (Printf.sprintf "sari\tlr, r%d, 1" i);
        ins ("bgeu\tlr, r13, " ^ (lab slow));
        ins (Printf.sprintf "add\tlr, r%d, lr" s);
        ins (Printf.sprintf "ldb\tr%d, 0(lr)" i);
        tagged i;
        ins ("j\t" ^ (lab done_));
        line (fun _ _ _ -> lab slow ^ ":\n");
        spill ();
        cargs := max !cargs 2;
        for k = 0 to 1 do
          get (spill_slot (!sp - k)) 13;
          ins (Printf.sprintf "stw\tr13, %d(sp)" (4 * k))
        done;
        sp := !sp - 2;
        c_call "ml_string_get";
        reload ();
        result ();
        line (fun _ _ _ -> lab done_ ^ ":\n")
    | CallC (f, n) ->
        spill ();
        cargs := max !cargs n;
        for k = 0 to n - 1 do
          get (spill_slot (!sp - k)) 13;
          ins (Printf.sprintf "stw\tr13, %d(sp)" (4 * k))
        done;
        sp := !sp - n;
        c_call f;
        reload ();
        result ()
    | Jmp l -> jump l; ins ("j\t" ^ (lab l)); dead := true
    | Jz l ->
        let r = !sp in
        decr sp; jump l; ins "li\tr13, 1";
        ins (Printf.sprintf "beq\tr%d, r13, %s" r (lab l))
    | Jnz l ->
        let r = !sp in
        decr sp; jump l; ins "li\tr13, 1";
        ins (Printf.sprintf "bne\tr%d, r13, %s" r (lab l))
    | Drop -> decr sp
    | Ret ->
        ins (Printf.sprintf "mov\tr13, r%d" !sp);
        decr sp; epilogue (); ins "ret"; dead := true
    | Raise ->
        ins (Printf.sprintf "mov\tr13, r%d" !sp);
        ins "la\tlr, ml_raise"; ins "jalr\tzero, 0(lr)"; dead := true
    | TryEnter (k, handler) ->
        (* the record: sp, r12, the handler's address (call's link: the
         * j after it), the previous record *)
        spill ();
        Hashtbl.replace catch_at k !sp;
        tries := max !tries (k + 1);
        let set = label () in
        ins ("call\t" ^ (lab set));
        ins ("j\t" ^ (lab handler));
        line (fun _ _ _ -> lab set ^ ":\n");
        at k 0 ((fun x0 -> Printf.sprintf "stw\tsp, %d(sp)" x0));
        at k 4 ((fun x0 -> Printf.sprintf "stw\tr12, %d(sp)" x0));
        at k 8 ((fun x0 -> Printf.sprintf "stw\tlr, %d(sp)" x0));
        ins "la\tlr, ml_handler";
        ins "ldw\tr13, 0(lr)";
        at k 12 ((fun x0 -> Printf.sprintf "stw\tr13, %d(sp)" x0));
        at k 0 ((fun x0 -> Printf.sprintf "addi\tr13, sp, %d" x0));
        ins "stw\tr13, 0(lr)"
    | TryExit k ->
        at k 12 ((fun x0 -> Printf.sprintf "ldw\tr13, %d(sp)" x0));
        ins "la\tlr, ml_handler"; ins "stw\tr13, 0(lr)")
    code;
  if nparams > 10 then
    error
      (name ^ ": " ^ string_of_int nparams
       ^ " parameters (tiny-machine passes 10 at most)");
  let f = nslots + !maxsp and c = 4 * !cargs in
  let m = (record c !tries + 7) land lnot 7 in
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
  flush ();
  List.iter (fun l -> Buffer.add_string text (l f m c)) (List.rev !lines)

(*****************************************************************************)
(* Data: static blocks *)
(*****************************************************************************)

(* a word of data: a number, a function's code, or a static block's
 * value (its first field's address) *)
type dword = DNum of string | DCode of string | DVal of string

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
let exn_id c = "ml_exn_" ^ c
let exn_const c = "ml_exv_" ^ c

(* (old: 2L, 1L, literals tiny-ml does not read) *)
let tagged n = Int64.add (Int64.mul (Int64.of_int 2) (Int64.of_int n)) Int64.one
