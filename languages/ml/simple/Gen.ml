(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Gen.mli *)

open Ir

(* what differs between the machines *)
type mach = {
  arch : Asm.arch;
  w : int;                  (* a word's bytes *)
  mov : string;             (* a word's move *)
  nregs : int;              (* the stack machine's registers, from R1 *)
  tmp : int;                (* scratch *)
  vsp : int;                (* the value stack's top *)
  sp : string;
  link : string;
  frame : string;           (* TEXT's: no frame of mini-ld's *)
  aapcs : bool;             (* C's arguments: gcc's, R0-R3 then 0(SP); else 5c's, R0 then w*(i+1)(SP) *)
}

(* (vsp, R10 on arm: the value stack's top, handed to C in ml_vsp and
 * taken back after each call of it, c_bl: the conventions between ML
 * and C are listed in ssa's Emit) *)
let arm = { arch = Arm; w = 4; mov = "MOVW"; nregs = 8; tmp = 9; vsp = 10; sp = "R13"; link = "R14"; frame = "$-4"; aapcs = false }
let arm64 = { arch = Arm64; w = 8; mov = "MOV"; nregs = 15; tmp = 16; vsp = 26; sp = "RSP"; link = "R30"; frame = "$-8"; aapcs = false }
let gnu m = { m with aapcs = true }
let arch m = m.arch
let error fmt = Printf.ksprintf failwith fmt
let sprintf = Printf.sprintf

(* an ML integer tagged, in a word *)
let tagged m n =
  let v = Int64.add (Int64.mul 2L (Int64.of_int n)) 1L in
  if m.w = 4 then Int64.of_int32 (Int64.to_int32 v) else v

let round n a = (n + a - 1) / a * a

(* a slot at off (negative) from the value stack's top; on arm64 below
 * -256 its address computed in R19 first: for such an offset 7l's, and
 * so mini-ld's, constant is an ADD from SP (bugs/goken.md 24) *)
let slot_ref m off =
  if m.arch = Arm64 && off < -256 then sprintf "\tSUB\t$%d, R%d, R19\n" (-off) m.vsp, "0(R19)"
  else "", sprintf "%d(R%d)" off m.vsp
let glabels = ref 0
let glabel () = incr glabels; sprintf "M%d" !glabels

(*****************************************************************************)
(* A function *)
(*****************************************************************************)

(* The frames. On the value stack, f words below its top (raised by f at
 * the entry): slot 0 the closure, then the parameters, the variables,
 * and a slot per register of the stack machine, where a call or an
 * allocation spills it. On the machine stack, m bytes: the link at 0,
 * then C's outgoing arguments (5c's and 7c's: the first in R0, the
 * i-th at w*(i+1)), then a handler's record, 4 words, each from c. They
 * are known at the end, so each line is a function of them. *)
let func m out (fn : func) =
  let w = m.w and mov = m.mov and vsp = m.vsp in
  let lines = ref [] in
  let line f = lines := f :: !lines in
  let ins fmt = Printf.ksprintf (fun s -> line (fun _ _ _ -> "\t" ^ s ^ "\n")) fmt in
  let lab l = line (fun _ _ _ -> l ^ ":\n") in
  let sp = ref 0 and maxsp = ref 0 and tries = ref 0 and cargs = ref (if m.arch = Arm then 1 else 0) and dead = ref false in
  let depth_at = Hashtbl.create 16 and catch_at = Hashtbl.create 4 in
  let get i r = line (fun f _ _ -> let pre, a = slot_ref m (w * (i - f)) in sprintf "%s\t%s\t%s, R%d\n" pre mov a r) in
  let put r i = line (fun f _ _ -> let pre, a = slot_ref m (w * (i - f)) in sprintf "%s\t%s\tR%d, %s\n" pre mov r a) in
  let spill_slot r = fn.nslots + r - 1 in
  let push () =
    incr sp;
    if !sp > m.nregs then error "%s: an expression too deep" fn.name;
    maxsp := max !maxsp !sp;
    !sp in
  let spill () = for r = 1 to !sp do put r (spill_slot r) done in
  let reload () = for r = 1 to !sp do get (spill_slot r) r done in
  let result () = ins "%s\tR0, R%d" mov (push ()) in
  let jump l = Hashtbl.replace depth_at l !sp in
  (* the link's slot: 0, or above gcc's outgoing arguments (4 words) *)
  let link = if m.aapcs then 4 * w else 0 in
  let epilogue () =
    line (fun f _ _ -> sprintf "\tSUB\t$%d, R%d\n" (w * f) vsp);
    ins "%s\t%d(%s), %s" mov link m.sp m.link;
    line (fun _ m' _ -> sprintf "\tADD\t$%d, %s\n" m' m.sp)
  in
  let record c k = c + (4 * w * k) in
  let at k d f = line (fun _ _ c -> "\t" ^ f (record c k + d) ^ "\n") in
  let shift = function Lsl -> (match m.arch with Arm -> "SLL" | Arm64 -> "LSL") | Lsr -> (match m.arch with Arm -> "SRL" | Arm64 -> "LSR")
                     | _ -> (match m.arch with Arm -> "SRA" | Arm64 -> "ASR") in
  let cond = function Eq -> "EQ" | Ne -> "NE" | Lt -> "LT" | Le -> "LE" | Gt -> "GT" | Ge -> "GE" in
  (* r's truth after a CMP, 1 (true) or 0, tagged, into d *)
  let set_bool r d =
    match m.arch with
    | Arm -> ins "MOVW\t$1, R%d" d; ins "MOVW.%s\t$3, R%d" (cond r) d
    | Arm64 -> ins "MOV\t$3, R%d" d; ins "B%s\t2(PC)" (cond r); ins "MOV\t$1, R%d" d
  in
  let branch_zero nonzero r l =
    match m.arch with
    | Arm -> ins "CMP\t$0, R%d" r; ins "%s\t%s" (if nonzero then "BNE" else "BEQ") l
    | Arm64 -> ins "%s\tR%d, %s" (if nonzero then "CBNZ" else "CBZ") r l
  in
  (* a call of C: the value stack's top handed over in ml_vsp, and
   * taken back after, the C free to use its register (ssa's Emit) *)
  let c_bl f =
    ins "%s\tR%d, ml_vsp(SB)" mov vsp;
    ins "BL\t%s(SB)" f;
    ins "%s\tml_vsp(SB), R%d" mov vsp
  in
  (* a call of C: its arguments from the slots, a..., R0 first *)
  let call_c f n =
    cargs := max !cargs n;
    get (spill_slot !sp) 0;
    for k = 1 to n - 1 do
      if m.aapcs && k < 4 then get (spill_slot (!sp - k)) k
      else (get (spill_slot (!sp - k)) m.tmp; ins "%s\tR%d, %d(%s)" mov m.tmp (if m.aapcs then w * (k - 4) else w * (k + 1)) m.sp)
    done;
    sp := !sp - n;
    c_bl f
  in
  (* a b by a op b in b's register *)
  let bin f = let a = !sp in decr sp; f a !sp in
  (* (the runtime's function for each of Lower's primitives: their
   * instructions where they are used, open-coded, are ssa's Emit's;
   * here a call each, the simple path)
   * old: Float2, Float1, FloatOfInt, IntOfFloat, Alloc and a float's
   * Poly compare in place too, ByteGet, ByteSet, StrLen and FloatCmp
   * always: Emit's ways, removed 2026-10-27 *)
  let op o =
    let a = !sp in
    match o with
    | Add -> bin (fun a b -> ins "ADD\tR%d, R%d, R%d" b a b; ins "SUB\t$1, R%d" b)
    | Sub -> bin (fun a b -> ins "SUB\tR%d, R%d, R%d" b a b; ins "ADD\t$1, R%d" b)
    | Mul -> bin (fun a b -> ins "SUB\t$1, R%d" a; ins "%s\t$1, R%d" (shift Asr) b; ins "MUL\tR%d, R%d, R%d" b a b; ins "ADD\t$1, R%d" b)
    | Div | Mod ->
        bin (fun a b ->
          ins "%s\t$1, R%d" (shift Asr) a;
          ins "%s\t$1, R%d" (shift Asr) b;
          ins "%s\tR%d, R%d, R%d" (match m.arch, o with Arm, Div -> "DIV" | Arm, _ -> "MOD" | _, Div -> "SDIV" | _ -> "REM") b a b;
          ins "%s\t$1, R%d" (shift Lsl) b;
          ins "ADD\t$1, R%d" b)
    | And -> bin (fun a b -> ins "AND\tR%d, R%d, R%d" b a b)
    | Or -> bin (fun a b -> ins "ORR\tR%d, R%d, R%d" b a b)
    | Xor -> bin (fun a b -> ins "EOR\tR%d, R%d, R%d" b a b; ins "ORR\t$1, R%d" b)
    | Lsl -> bin (fun a b -> ins "SUB\t$1, R%d" a; ins "%s\t$1, R%d" (shift Asr) b; ins "%s\tR%d, R%d, R%d" (shift Lsl) b a b; ins "ORR\t$1, R%d" b)
    | Lsr | Asr -> bin (fun a b -> ins "%s\t$1, R%d" (shift Asr) b; ins "%s\tR%d, R%d, R%d" (shift o) b a b; ins "ORR\t$1, R%d" b)
    | Cmp r -> bin (fun a b -> ins "CMP\tR%d, R%d" b a; set_bool r b)
    | Poly r ->
        (* integers compared here, the others by the runtime *)
        bin (fun a b ->
          let slow = glabel () and ok = glabel () in
          ins "AND\tR%d, R%d, R%d" b a m.tmp;
          ins "AND\t$1, R%d" m.tmp;
          branch_zero false m.tmp slow;
          ins "CMP\tR%d, R%d" b a;
          set_bool r b;
          ins "B\t%s" ok;
          lab slow;
          incr sp;
          spill ();
          call_c (Lower.poly_function r) 2;
          reload ();
          incr sp;
          ins "%s\tR0, R%d" mov !sp;
          lab ok)
    | Neg -> (match m.arch with Arm -> ins "RSB\t$0, R%d, R%d" a a | Arm64 -> ins "NEG\tR%d, R%d" a a); ins "ADD\t$2, R%d" a
    | Not -> ins "EOR\t$2, R%d" a
    | IsInt -> ins "AND\t$1, R%d" a; ins "%s\t$1, R%d" (shift Lsl) a; ins "ORR\t$1, R%d" a
    | Tag -> ins "MOVBU\t%d(R%d), R%d" (-w) a a; ins "%s\t$1, R%d" (shift Lsl) a; ins "ORR\t$1, R%d" a
    | Size -> ins "%s\t%d(R%d), R%d" mov (-w) a a; ins "%s\t$10, R%d" (shift Lsr) a; ins "%s\t$1, R%d" (shift Lsl) a; ins "ORR\t$1, R%d" a
  in
  (* a block's i-th field's address into i's register, the index
   * checked against the block's size *)
  let index b i =
    ins "%s\t%d(R%d), R%d" mov (-w) b m.tmp;
    ins "%s\t$10, R%d" (shift Lsr) m.tmp;
    ins "%s\t$1, R%d" (shift Asr) i;
    ins "CMP\tR%d, R%d" m.tmp i;
    ins "BLO\t2(PC)";
    ins "BL\tcaml_array_bound_error(SB)";
    ins "%s\t$%d, R%d" (shift Lsl) (if w = 4 then 2 else 3) i;
    ins "ADD\tR%d, R%d" b i
  in
  (* OPTIMIZATION (generations: the runtime's gc.c): a block stored in
   * a field, ml_modify called (the start object's: it remembers the
   * field if the block is young and the field old), its value in R0
   * and the field's address, put by [field], in the scratch register;
   * nothing when the value is an integer. Not with gcc's C (-gas), whose
   * runtime has one generation. *)
  let modify v field =
    if not m.aapcs then begin
      let skip = glabel () in
      ins "AND\t$1, R%d, R0" v;
      branch_zero true 0 skip;
      ins "%s\tR%d, R0" mov v;
      field ();
      ins "BL\tml_modify(SB)";
      lab skip
    end
  in
  List.iter (fun i ->
    match i with
    | Label l ->
        (* after a jump, the depth the label was jumped to with *)
        (match Hashtbl.find_opt depth_at l with Some d when !dead -> sp := d | _ -> ());
        dead := false;
        lab (sprintf "L%d" l)
    | Catch k -> dead := false; sp := Hashtbl.find catch_at k; reload (); result ()
    | _ when !dead -> ()
    | Int n -> ins "%s\t$%Ld, R%d" mov (tagged m n) (push ())
    | Block s -> ins "%s\t$%s+%d(SB), R%d" mov s w (push ())
    | Sym s -> ins "%s\t$%s(SB), R%d" mov s (push ())
    | Get i -> get i (push ())
    | Set i -> put !sp i; decr sp
    | GetG g -> ins "%s\t%s(SB), R%d" mov g (push ())
    | SetG g -> ins "%s\tR%d, %s(SB)" mov !sp g; decr sp
    | Field k -> ins "%s\t%d(R%d), R%d" mov (w * k) !sp !sp
    | SetField (k, imm) ->
        let b = !sp in
        ins "%s\tR%d, %d(R%d)" mov (b - 1) (w * k) b;
        if not imm then modify (b - 1) (fun () -> ins "ADD\t$%d, R%d, R%d" (w * k) b m.tmp);
        sp := b - 2
    | Index -> let b = !sp in decr sp; index b !sp; ins "%s\t0(R%d), R%d" mov !sp !sp
    | SetIndex imm ->
        let b = !sp in
        index b (b - 1);
        ins "%s\tR%d, 0(R%d)" mov (b - 2) (b - 1);
        if not imm then modify (b - 2) (fun () -> ins "%s\tR%d, R%d" mov (b - 1) m.tmp);
        sp := b - 3
    (* the runtime's function, by the operands' count (a Float.Array's
     * float: a new float read, none written; ssa's Unbox: the
     * processor's load and store) *)
    | StrLen | Float1 _ | FloatOfInt | IntOfFloat | FloatRound _
    | Int32 Neg | Int32OfInt | Int32ToInt ->
        spill (); call_c (Lower.runtime_function i) 1; reload (); result ()
    | ByteGet _ | FloatCmp _ | Float2 _ | FloatIndex _ | Int32 _ | BytesGet _ ->
        spill (); call_c (Lower.runtime_function i) 2; reload (); result ()
    | FloatCall (_, _, n) ->
        spill (); call_c (Lower.runtime_function i) n; reload (); result ()
    | ByteSet _ | FloatSetIndex _ | BytesSet _ ->
        spill (); call_c (Lower.runtime_function i) 3; reload ()
    | Alloc (tag, n) ->
        (* the collector may run: every value in a slot, the fields read back *)
        spill ();
        cargs := max !cargs 2;
        ins "%s\t$%d, R0" mov n;
        if m.aapcs then ins "%s\t$%d, R1" mov tag
        else (ins "%s\t$%d, R%d" mov tag m.tmp; ins "%s\tR%d, %d(%s)" mov m.tmp (2 * w) m.sp);
        c_bl "ml_alloc";
        for k = 0 to n - 1 do get (spill_slot (!sp - k)) m.tmp; ins "%s\tR%d, %d(R0)" mov m.tmp (w * k) done;
        sp := !sp - n;
        reload ();
        result ()
    | Op o -> op o
    | Call (t, slots, tail) ->
        spill ();
        List.iteri (fun k s -> if k <= m.nregs then get s k) slots;
        (* the arguments past the registers: each where the callee's
         * slot k will be, k words above the top (its frame starts at
         * the top), and its entry leaves them there. Nothing allocates
         * before it raises the top, so they need not be seen by the
         * collector meanwhile. A tail call's callee has its frame
         * where this one's is: they are copied down into this frame's
         * slots after all are read, so that none is overwritten
         * before it is. *)
        let extra = List.filteri (fun k _ -> k > m.nregs) (List.mapi (fun k s -> k, s) slots) in
        List.iter (fun (k, s) -> get s m.tmp; ins "%s\tR%d, %d(R%d)" mov m.tmp (w * k) vsp) extra;
        if tail then List.iter (fun (k, _) -> ins "%s\t%d(R%d), R%d" mov (w * k) vsp m.tmp; put m.tmp k) extra;
        let target = match t with Direct f -> f ^ "(SB)" | Code k -> ins "%s\t%d(R0), R%d" mov (w * k) m.tmp; sprintf "(R%d)" m.tmp in
        if tail then (epilogue (); ins "B\t%s" target; dead := true) else (ins "BL\t%s" target; reload (); result ())
    | CallC (f, n) -> spill (); call_c f n; reload (); result ()
    | Jmp l -> jump l; ins "B\tL%d" l; dead := true
    | Jz l -> let r = !sp in decr sp; jump l; ins "CMP\t$1, R%d" r; ins "BEQ\tL%d" l
    | Jnz l -> let r = !sp in decr sp; jump l; ins "CMP\t$1, R%d" r; ins "BNE\tL%d" l
    (* as Emit's *)
    | Switch ls ->
        let r = !sp in
        decr sp;
        List.iter jump ls;
        ins "%s\t$1, R%d, R%d" (shift Asr) r m.tmp;
        (match m.arch with
         | Arm -> ins "CASE\tR%d" m.tmp; ins "BCASE\tL%d" (List.hd ls)
         | Arm64 -> ins "CASE\tR%d, R%d" m.tmp r);
        List.iter (fun l -> ins "BCASE\tL%d" l) ls;
        dead := true
    | Drop -> decr sp
    | Ret ->
        ins "%s\tR%d, R0" mov !sp;
        decr sp;
        epilogue ();
        ins "%s" (match m.arch with Arm -> "RET" | Arm64 -> "RET\t(R30)");
        dead := true
    | Raise -> ins "%s\tR%d, R0" mov !sp; ins "B\tml_raise(SB)"; dead := true
    | TryEnter (k, handler) ->
        spill ();
        Hashtbl.replace catch_at k !sp;
        jump handler;
        tries := max !tries (k + 1);
        ins "%s\t%s, R0" mov m.sp;
        at k 0 (sprintf "ADD\t$%d, R0");
        ins "BL\tml_try(SB)";
        branch_zero true 0 (sprintf "L%d" handler)
    | TryExit k -> at k (3 * w) (fun o -> sprintf "%s\t%d(%s), R%d" mov o m.sp m.tmp); ins "%s\tR%d, ml_handler(SB)" mov m.tmp)
    fn.code;
  if m.aapcs && !cargs > 8 then error "%s: a call of C with %d arguments" fn.name !cargs;
  let f = fn.nslots + !maxsp and c = round (max (w * (!cargs + 1)) (link + w)) 16 in
  let msize = record c !tries in
  let pr fmt = Printf.bprintf out fmt in
  (* (the function's line, for the object: CLI's lines) *)
  pr "\t// line %d\n\tTEXT\t%s(SB), %s\n" fn.line fn.name m.frame;
  pr "\tSUB\t$%d, %s\n\t%s\t%s, %d(%s)\n\tADD\t$%d, R%d\n" msize m.sp mov m.link link m.sp (w * f) vsp;
  let slot i = let pre, a = slot_ref m (w * (i - f)) in pr "%s" pre; a in
  (* (the parameters past the registers already in their slots: Call) *)
  for i = 0 to min fn.nparams m.nregs do let a = slot i in pr "\t%s\tR%d, %s\n" mov i a done;
  (* the other slots zeroed: the collector scans them *)
  (match m.arch with
   | Arm64 -> for i = fn.nparams + 1 to f - 1 do let a = slot i in pr "\tMOV\tZR, %s\n" a done
   | Arm -> if f > fn.nparams + 1 then pr "\tMOVW\t$0, R%d\n" m.tmp; for i = fn.nparams + 1 to f - 1 do pr "\tMOVW\tR%d, %s\n" m.tmp (snd (slot_ref m (w * (i - f)))) done);
  List.iter (fun l -> Buffer.add_string out (l f msize c)) (List.rev !lines)

(*****************************************************************************)
(* Data *)
(*****************************************************************************)

let header n tag = string_of_int ((n lsl 10) lor tag)

let words m out sym ws =
  List.iteri (fun i v -> Printf.bprintf out "\tDATA\t%s+%d(SB)/%d, $%s\n" sym (m.w * i) m.w v) ws;
  Printf.bprintf out "\tGLOBL\t%s(SB), $%d\n" sym (m.w * List.length ws)

let datum m out = function
  | String (sym, s) ->
      (* its words, the last byte the number of the others that are padding *)
      let n = (String.length s / m.w) + 1 in
      let b = Bytes.make (m.w * n) '\000' in
      Bytes.blit_string s 0 b 0 (String.length s);
      Bytes.set b ((m.w * n) - 1) (Char.chr ((m.w * n) - 1 - String.length s));
      let word i = if m.w = 4 then Int32.to_string (Bytes.get_int32_le b (4 * i)) else Int64.to_string (Bytes.get_int64_le b (8 * i)) in
      words m out sym (header n 252 :: List.init n word)
  | Float (sym, f) ->
      let bits = Int64.bits_of_float (float_of_string f) in
      if m.w = 8 then words m out sym [ header 1 253; Int64.to_string bits ]
      else words m out sym [ header 2 253; Int64.to_string (Int64.logand bits 0xffffffffL); Int64.to_string (Int64.shift_right_logical bits 32) ]
  (* the runtime's Int32_tag and Int64_tag; an int32 in a word, its sign
   * extended; 0xffffffffL is OCaml's -1l *)
  | Boxed_int (sym, 32, n) -> words m out sym [ header 1 254; Int32.to_string (Int32.of_string n) ]
  | Boxed_int (sym, _, n) ->
      let bits = Int64.of_string n in
      if m.w = 8 then words m out sym [ header 1 255; Int64.to_string bits ]
      else words m out sym [ header 2 255; Int64.to_string (Int64.logand bits 0xffffffffL); Int64.to_string (Int64.shift_right_logical bits 32) ]
  | Closure (sym, entry, code) -> words m out sym [ header 2 247; entry ^ "(SB)"; code ^ "(SB)" ]
  | Exception (sym, name) -> words m out sym [ header 1 0; sprintf "%s+%d(SB)" name m.w ]
  | Global (sym, None) -> Printf.bprintf out "\tGLOBL\t%s(SB), $%d\n" sym m.w
  | Global (sym, Some b) -> words m out sym [ sprintf "%s+%d(SB)" b m.w ]
  | Roots (sym, gs) -> words m out sym (string_of_int (List.length gs) :: List.map (fun g -> g ^ "(SB)") gs)

let unit_ m (u : unit_) =
  let out = Buffer.create 65536 in
  List.iter (func m out) u.funcs;
  List.iter (datum m out) u.data;
  Buffer.contents out

(*****************************************************************************)
(* The program's start *)
(*****************************************************************************)

let startup m compile units =
  let out = Buffer.create 4096 in
  let pr fmt = Printf.bprintf out fmt in
  let mov = m.mov and w = m.w and t = m.tmp in
  (* from C: the value stack's base, then the units' initializations *)
  pr "\tTEXT\tml_start(SB), %s\n\t%s\tR0, R%d\n\tB\tml_program(SB)\n" m.frame mov m.vsp;
  (* the handler's record in R0: SP, the value stack's top, the return
   * address (where raise returns), the previous record *)
  pr "\tTEXT\tml_try(SB), %s\n" m.frame;
  (match m.arch with
   | Arm64 -> pr "\tMOV\tRSP, R%d\n\tMOV\tR%d, 0(R0)\n" t t
   | Arm -> pr "\tMOVW\tR13, 0(R0)\n");
  pr "\t%s\tR%d, %d(R0)\n\t%s\t%s, %d(R0)\n\t%s\tml_handler(SB), R%d\n\t%s\tR%d, %d(R0)\n" mov m.vsp w mov m.link (2 * w) mov t mov t (3 * w);
  pr "\t%s\tR0, ml_handler(SB)\n\t%s\t$0, R0\n\t%s\n" mov mov (match m.arch with Arm -> "RET" | Arm64 -> "RET\t(R30)");
  (* the exception in R0: back to the latest record *)
  (* (first, for a trace, when the runtime asks (ml_tracing): the 16
   * top words of the machine's stack kept in ml_raise_words, or those
   * up to the handler's own stack pointer, and how many of the 16
   * were not there in ml_raise_left; the runtime's exceptions.c reads
   * the return addresses in them. No register is anyone's at a raise
   * but R0's exception.) *)
  pr "\tTEXT\tml_raise(SB), %s\n\t%s\tml_handler(SB), R%d\n" m.frame mov t;
  pr "\t%s\tml_tracing(SB), R1\n\tCMP\t$0, R1\n\tBEQ\t15(PC)\n" mov;
  pr "\t%s\t0(R%d), R1\n\t%s\t%s, R2\n\t%s\t$ml_raise_words(SB), R3\n\t%s\t$16, R4\n" mov t mov (match m.arch with Arm -> "R13" | Arm64 -> "RSP") mov mov;
  pr "\tCMP\tR1, R2\n\tBHS\t8(PC)\n\t%s\t0(R2), R5\n\t%s\tR5, 0(R3)\n\tADD\t$%d, R2\n\tADD\t$%d, R3\n\tSUB\t$1, R4\n\tCMP\t$0, R4\n\tBNE\t-8(PC)\n" mov mov w w;
  pr "\t%s\tR4, ml_raise_left(SB)\n" mov;
  (match m.arch with
   | Arm64 -> pr "\tMOV\t0(R%d), R18\n\tMOV\tR18, RSP\n\tMOV\t8(R%d), R26\n\tMOV\t24(R%d), R18\n\tMOV\tR18, ml_handler(SB)\n\tMOV\t16(R%d), R18\n\tB\t(R18)\n" t t t t
   | Arm -> pr "\tMOVW\t0(R9), R13\n\tMOVW\t4(R9), R10\n\tMOVW\t12(R9), R14\n\tMOVW\tR14, ml_handler(SB)\n\tMOVW\t8(R9), R9\n\tB\t(R9)\n");
  (* from C, a function of ML's called (the runtime's callback: a
   * kernel's trap): the closure in R0 as C gave it, its argument C's
   * second, the value stack's top back in its register, the closure's
   * code for one argument. mini-ld's frame keeps the link. Not with
   * gcc's C (-gas): it keeps values in registers across a call (R4-R11),
   * which are the stack machine's. *)
  (match m.arch with
   | Arm64 -> pr "\tTEXT\tml_callback(SB), $16\n\tMOV\ta+8(FP), R1\n\tMOV\tml_vsp(SB), R%d\n\tMOV\t0(R0), R%d\n\tBL\t(R%d)\n\tRETURN\n" m.vsp t t
   | Arm when m.aapcs -> ()
   | Arm -> pr "\tTEXT\tml_callback(SB), $4\n\tMOVW\ta+4(FP), R1\n\tMOVW\tml_vsp(SB), R%d\n\tMOVW\t0(R0), R%d\n\tBL\t(R%d)\n\tRET\n" m.vsp t t);
  (* from C, the runtime's thread_switch: R0 has two addresses, the
   * running thread's context and another's, each three words: the
   * machine's stack pointer, the return address, the value stack's top
   * (its register). The first saved, the second put back: the return is
   * into the other thread, where it called here (or at its start:
   * thread_new's context). C keeps nothing else in a register across a
   * call (5c's and 7c's). *)
  (match m.arch with
   | Arm64 -> pr "\tTEXT\tml_swtch(SB), $-8\n\tMOV\t0(R0), R1\n\tMOV\t8(R0), R2\n\tMOV\tRSP, R%d\n\tMOV\tR%d, 0(R1)\n\tMOV\tR30, 8(R1)\n\tMOV\tR%d, 16(R1)\n\tMOV\t16(R2), R%d\n\tMOV\t8(R2), R30\n\tMOV\t0(R2), R%d\n\tMOV\tR%d, RSP\n\tRET\t(R30)\n" t t m.vsp m.vsp t t
   | Arm when m.aapcs -> ()
   | Arm -> pr "\tTEXT\tml_swtch(SB), $-4\n\tMOVW\t0(R0), R1\n\tMOVW\t4(R0), R2\n\tMOVW\tR13, 0(R1)\n\tMOVW\tR14, 4(R1)\n\tMOVW\tR%d, 8(R1)\n\tMOVW\t8(R2), R%d\n\tMOVW\t4(R2), R14\n\tMOVW\t0(R2), R13\n\tRET\n" m.vsp m.vsp);
  (* the write barrier (generations: the runtime's gc.c, and Gen's
   * modify): a block in R0 stored at the address in the scratch
   * register; the address remembered, in ml_refs, when the block is
   * young and the field not (an old block made to point to a young
   * one). Only R0 and the scratch register changed (R1 kept on the
   * machine's stack): the code that calls keeps its values in the
   * others. At the table's soon end (ml_refs_end: gc.c's refs_soon), a
   * minor collection asked for (ml_limit at ml_hp), the end the hard
   * one; at that one, the last entry written again, and ml_refs_lost
   * (the next minor collection scans the old blocks). *)
  if not m.aapcs then begin
    let sz = if m.arch = Arm then 8 else 16 in
    let old = glabel () and room = glabel () and fin = glabel () and lost = glabel () in
    pr "\tTEXT\tml_modify(SB), %s\n\tSUB\t$%d, %s\n\t%s\tR1, 0(%s)\n" m.frame sz m.sp mov m.sp;
    pr "\t%s\tml_young_lo(SB), R1\n\tCMP\tR1, R0\n\tBLO\t%s\n" mov fin;
    pr "\t%s\tml_young_hi(SB), R1\n\tCMP\tR1, R0\n\tBHS\t%s\n" mov fin;
    pr "\tCMP\tR1, R%d\n\tBHS\t%s\n\t%s\tml_young_lo(SB), R1\n\tCMP\tR1, R%d\n\tBHS\t%s\n" t old mov t fin;
    pr "%s:\n\t%s\tml_refs(SB), R1\n\t%s\tml_refs_end(SB), R0\n\tCMP\tR0, R1\n\tBLO\t%s\n" old mov mov room;
    pr "\t%s\tml_hp(SB), R0\n\t%s\tR0, ml_limit(SB)\n" mov mov;
    pr "\t%s\tml_refs_hard(SB), R0\n\tCMP\tR0, R1\n\tBEQ\t%s\n\t%s\tR0, ml_refs_end(SB)\n\tB\t%s\n" mov lost mov room;
    pr "%s:\n\tSUB\t$%d, R1\n\t%s\t$1, R0\n\t%s\tR0, ml_refs_lost(SB)\n" lost w mov mov;
    pr "%s:\n\t%s\tR%d, 0(R1)\n\tADD\t$%d, R1\n\t%s\tR1, ml_refs(SB)\n" room mov t w mov;
    pr "%s:\n\t%s\t0(%s), R1\n\tADD\t$%d, %s\n\t%s\n" fin mov m.sp sz m.sp (match m.arch with Arm -> "RET" | Arm64 -> "RET\t(R30)")
  end;
  (* the square root: the processor's instruction on arm64, correctly
   * rounded and its own NaN, as OCaml's (the C library's is computed,
   * a bit off sometimes: bugs/ix.md); the runtime's C calls here, a
   * double given and returned as 7c's and 5c's are. On arm the
   * instruction by its word (VFP's vsqrt.f64 d0, d0: 5l has no name for
   * it). *)
  (match m.arch with
   | Arm64 -> pr "\tTEXT\tml_fsqrt(SB), $0\n\tFMOVD\ta+0(FP), F0\n\tFSQRTD\tF0, F0\n\tRETURN\n"
   | Arm when m.aapcs -> ()
   | Arm -> pr "\tTEXT\tml_fsqrt(SB), $-4\n\tMOVD\ta+0(FP), F0\n\tWORD\t$0xeeb10bc0\n\tRET\n");
  (* a unit's initialization and its roots are named, not asked for
   * (mini-ld's weak, Link.weak: 32): a unit of a library that the
   * program does not use is not linked, its call below no call and its
   * roots' address 0, which the collector passes *)
  (* (not for GNU's ld, -gas: its programs are given every unit) *)
  if not m.aapcs then
    List.iter (fun u -> pr "\tGLOBL\t%s.Init(SB), $32, $0\n\tGLOBL\t%s.Roots(SB), $32, $0\n" (Lower.mangle u) (Lower.mangle u)) units;
  (* the units' initializations, in a handler printing an uncaught
   * exception *)
  let handler = 1 in
  let code =
    [ TryEnter (0, handler) ]
    @ List.concat_map (fun u -> [ Call (Direct (Lower.mangle u ^ ".Init"), [ 0 ], false); Drop ]) units
    @ [ TryExit 0; Int 0; Ret; Label handler; Catch 0; CallC ("ml_uncaught", 1); Ret ]
  in
  (* it and the curry functions (once for all the units) compiled by
   * compile: this back end's, or ssa's (CLI, -ssa) *)
  Buffer.add_string out (compile ({ name = "ml_program"; nparams = 0; nslots = 1; code; line = 0 } :: Lower.curry_funcs ()));
  words m out "ml_units" (string_of_int (List.length units) :: List.map (fun u -> Lower.mangle u ^ ".Roots(SB)") units);
  Buffer.contents out
