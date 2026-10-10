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
(* OPTIMIZATION (alloc_in_place): a block is taken from the heap here,
 * the runtime's ml_alloc written out (its two words, ml_hp and
 * ml_limit: the heap's next free word and its end), and the runtime
 * called only when there is no room, for its collector: 9 instructions
 * where the call was 40, and no value put in its slot and read back.
 * (off: mini-ml -calls; not with gcc's C, -gas) *)
let alloc_in_place = ref true
(* (a block's fields are stored below the new top: few enough for the
 * offset to be a small one, arm64's) *)
let alloc_most = 16

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
    (* (ml_curry8: a function of 8 parameters, one more than arm's registers take) *)
    if !sp > m.nregs then error "%s: an expression too deep (or a function of more than %d parameters: group some in a tuple)" fn.name (m.nregs - 1);
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
  (* a call of C: its arguments from the slots, a..., R0 first *)
  let call_c f n =
    cargs := max !cargs n;
    get (spill_slot !sp) 0;
    for k = 1 to n - 1 do
      if m.aapcs && k < 4 then get (spill_slot (!sp - k)) k
      else (get (spill_slot (!sp - k)) m.tmp; ins "%s\tR%d, %d(%s)" mov m.tmp (if m.aapcs then w * (k - 4) else w * (k + 1)) m.sp)
    done;
    sp := !sp - n;
    ins "%s\tR%d, ml_vsp(SB)" mov vsp;
    ins "BL\t%s(SB)" f
  in
  (* a b by a op b in b's register *)
  let bin f = let a = !sp in decr sp; f a !sp in
  let in_place () = !alloc_in_place && not m.aapcs in
  let fmov = match m.arch with Arm -> "MOVD" | Arm64 -> "FMOVD" in
  (* a float's block: its 8 bytes' words, the runtime's Double_tag *)
  let float_words = 8 / w and float_tag = 253 in
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
          (* OPTIMIZATION (alloc_in_place's switch): two floats compared
           * here too, by the processor (the runtime's compare, which
           * finds what its operands are, was 90 instructions; a shape's
           * place asks a dozen: is it turned, is it seen). Each a block
           * and a float by its header's tag; the conditions those that
           * are false of a number that is none, as the runtime's. *)
          if in_place () then begin
            let call = glabel () in
            let is_float x =
              ins "AND\t$1, R%d, R%d" x m.tmp; branch_zero true m.tmp call;
              ins "MOVBU\t%d(R%d), R%d" (-w) x m.tmp; ins "CMP\t$%d, R%d" float_tag m.tmp; ins "BNE\t%s" call in
            is_float a; is_float b;
            ins "%s\t0(R%d), F0" fmov a;
            ins "%s\t0(R%d), F1" fmov b;
            ins "%s\tF1, F0" (match m.arch with Arm -> "CMPD" | Arm64 -> "FCMPD");
            let c = match r with Eq -> "EQ" | Ne -> "NE" | Lt -> "MI" | Le -> "LS" | Gt -> "GT" | Ge -> "GE" in
            (match m.arch with
             | Arm -> ins "MOVW\t$1, R%d" b; ins "MOVW.%s\t$3, R%d" c b
             | Arm64 -> ins "MOV\t$3, R%d" b; ins "B%s\t2(PC)" c; ins "MOV\t$1, R%d" b);
            ins "B\t%s" ok;
            lab call
          end;
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
  (* a block of n words taken from the heap, its address in R0; to
   * [slow] with nothing changed when there is no room (ml_alloc's test) *)
  let take n tag slow =
    ins "%s\tml_hp(SB), R0" mov;
    ins "%s\tml_limit(SB), R%d" mov m.tmp;
    ins "ADD\t$%d, R0" (w * (n + 1));
    ins "CMP\tR%d, R0" m.tmp;
    ins "BHI\t%s" slow;
    ins "%s\tR0, ml_hp(SB)" mov;
    ins "%s\t$%d, R%d" mov ((n lsl 10) lor tag) m.tmp;
    ins "%s\tR%d, %d(R0)" mov m.tmp (- (w * (n + 1)));
    ins "SUB\t$%d, R0" (w * n)
  in
  (* F0 in a new float, the result; [f], the runtime's function of the
   * [n] operands still in their registers, called when there is no room *)
  let float_result f n =
    let slow = glabel () and ok = glabel () in
    take float_words float_tag slow;
    ins "%s\tF0, 0(R0)" fmov;
    ins "B\t%s" ok;
    lab slow;
    spill ();
    call_c f n;
    reload ();
    lab ok;
    result ()
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
    | SetField k -> ins "%s\tR%d, %d(R%d)" mov (!sp - 1) (w * k) !sp; sp := !sp - 2
    | Index -> let b = !sp in decr sp; index b !sp; ins "%s\t0(R%d), R%d" mov !sp !sp
    | SetIndex -> let b = !sp in index b (b - 1); ins "%s\tR%d, 0(R%d)" mov (b - 2) (b - 1); sp := b - 3
    (* a string's byte: the index untagged and added to the string's
     * address; the byte tagged when read, untagged (in the scratch
     * register) when written. No check: the unchecked accessors'. *)
    | ByteGet ->
        let s = !sp in
        decr sp;
        ins "%s\t$1, R%d" (shift Asr) !sp;
        ins "ADD\tR%d, R%d" s !sp;
        ins "MOVBU\t0(R%d), R%d" !sp !sp;
        ins "%s\t$1, R%d" (shift Lsl) !sp;
        ins "ORR\t$1, R%d" !sp
    | ByteSet ->
        let s = !sp in
        ins "%s\t$1, R%d" (shift Asr) (s - 1);
        ins "ADD\tR%d, R%d" s (s - 1);
        ins "%s\t$1, R%d, R%d" (shift Asr) (s - 2) m.tmp;
        ins "MOVB\tR%d, 0(R%d)" m.tmp (s - 1);
        sp := s - 3
    (* a string's length: its words' bytes, less one, less what its last
     * byte says is not its own (the runtime's length) *)
    | StrLen ->
        let s = !sp in
        ins "%s\t%d(R%d), R%d" mov (-w) s m.tmp;
        ins "%s\t$10, R%d" (shift Lsr) m.tmp;
        ins "%s\t$%d, R%d" (shift Lsl) (if w = 4 then 2 else 3) m.tmp;
        ins "SUB\t$1, R%d" m.tmp;
        ins "ADD\tR%d, R%d" m.tmp s;
        ins "MOVBU\t0(R%d), R%d" s s;
        ins "SUB\tR%d, R%d, R%d" s m.tmp s;
        ins "%s\t$1, R%d" (shift Lsl) s;
        ins "ORR\t$1, R%d" s
    | Float2 f when in_place () ->
        let a = !sp in
        ins "%s\t0(R%d), F0" fmov a;
        ins "%s\t0(R%d), F1" fmov (a - 1);
        ins "%s\tF1, F0"
          (match m.arch, f with
           | Arm, "caml_addfloat" -> "ADDD" | Arm, "caml_subfloat" -> "SUBD" | Arm, "caml_mulfloat" -> "MULD" | Arm, _ -> "DIVD"
           | Arm64, "caml_addfloat" -> "FADDD" | Arm64, "caml_subfloat" -> "FSUBD" | Arm64, "caml_mulfloat" -> "FMULD" | Arm64, _ -> "FDIVD");
        float_result f 2
    | Float1 f when in_place () && m.arch = Arm ->
        (* the float's two words, the sign's bit of the high one changed
         * (the runtime's, which does so too) *)
        let a = !sp and slow = glabel () and ok = glabel () in
        take float_words float_tag slow;
        ins "MOVW\t0(R%d), R%d" a m.tmp;
        ins "MOVW\tR%d, 0(R0)" m.tmp;
        ins "MOVW\t4(R%d), R%d" a m.tmp;
        ins "%s\t$0x80000000, R%d" (if f = "caml_negfloat" then "EOR" else "BIC") m.tmp;
        ins "MOVW\tR%d, 4(R0)" m.tmp;
        ins "B\t%s" ok;
        lab slow;
        spill ();
        call_c f 1;
        reload ();
        lab ok;
        result ()
    | Float1 f -> spill (); call_c f 1; reload (); result ()
    | FloatOfInt when in_place () ->
        ins "%s\t$1, R%d, R%d" (shift Asr) !sp m.tmp;
        ins "%s\tR%d, F0" (match m.arch with Arm -> "MOVWD" | Arm64 -> "SCVTFD") m.tmp;
        float_result "caml_floatofint" 1
    | IntOfFloat when in_place () ->
        let a = !sp in
        ins "%s\t0(R%d), F0" fmov a;
        ins "%s\tF0, R%d" (match m.arch with Arm -> "MOVDW" | Arm64 -> "FCVTZSD") a;
        ins "%s\t$1, R%d" (shift Lsl) a;
        ins "ORR\t$1, R%d" a
    | Float2 f -> spill (); call_c f 2; reload (); result ()
    | FloatOfInt -> spill (); call_c "caml_floatofint" 1; reload (); result ()
    | IntOfFloat -> spill (); call_c "caml_intoffloat" 1; reload (); result ()
    | Alloc (tag, n) when in_place () && n <= alloc_most ->
        (* the fields from their registers; with no room, from their
         * slots after the runtime's call, as below *)
        let slow = glabel () and ok = glabel () in
        take n tag slow;
        for k = 0 to n - 1 do ins "%s\tR%d, %d(R0)" mov (!sp - k) (w * k) done;
        ins "B\t%s" ok;
        lab slow;
        spill ();
        cargs := max !cargs 2;
        ins "%s\t$%d, R0" mov n;
        ins "%s\t$%d, R%d" mov tag m.tmp; ins "%s\tR%d, %d(%s)" mov m.tmp (2 * w) m.sp;
        ins "%s\tR%d, ml_vsp(SB)" mov vsp;
        ins "BL\tml_alloc(SB)";
        for k = 0 to n - 1 do get (spill_slot (!sp - k)) m.tmp; ins "%s\tR%d, %d(R0)" mov m.tmp (w * k) done;
        sp := !sp - n;
        reload ();
        lab ok;
        result ()
    | Alloc (tag, n) ->
        (* the collector may run: every value in a slot, the fields read back *)
        spill ();
        cargs := max !cargs 2;
        ins "%s\t$%d, R0" mov n;
        if m.aapcs then ins "%s\t$%d, R1" mov tag
        else (ins "%s\t$%d, R%d" mov tag m.tmp; ins "%s\tR%d, %d(%s)" mov m.tmp (2 * w) m.sp);
        ins "%s\tR%d, ml_vsp(SB)" mov vsp;
        ins "BL\tml_alloc(SB)";
        for k = 0 to n - 1 do get (spill_slot (!sp - k)) m.tmp; ins "%s\tR%d, %d(R0)" mov m.tmp (w * k) done;
        sp := !sp - n;
        reload ();
        result ()
    | Op o -> op o
    | Call (t, slots, tail) ->
        if List.length slots - 1 > m.nregs then error "%s: a call of %d arguments" fn.name (List.length slots - 1);
        spill ();
        List.iteri (fun k s -> get s k) slots;
        let target = match t with Direct f -> f ^ "(SB)" | Code k -> ins "%s\t%d(R0), R%d" mov (w * k) m.tmp; sprintf "(R%d)" m.tmp in
        if tail then (epilogue (); ins "B\t%s" target; dead := true) else (ins "BL\t%s" target; reload (); result ())
    | CallC (f, n) -> spill (); call_c f n; reload (); result ()
    | Jmp l -> jump l; ins "B\tL%d" l; dead := true
    | Jz l -> let r = !sp in decr sp; jump l; ins "CMP\t$1, R%d" r; ins "BEQ\tL%d" l
    | Jnz l -> let r = !sp in decr sp; jump l; ins "CMP\t$1, R%d" r; ins "BNE\tL%d" l
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
  pr "\tTEXT\t%s(SB), %s\n" fn.name m.frame;
  pr "\tSUB\t$%d, %s\n\t%s\t%s, %d(%s)\n\tADD\t$%d, R%d\n" msize m.sp mov m.link link m.sp (w * f) vsp;
  if fn.nparams > m.nregs then error "%s: %d parameters (at most %d: group some in a tuple)" fn.name fn.nparams (m.nregs - 1);
  let slot i = let pre, a = slot_ref m (w * (i - f)) in pr "%s" pre; a in
  for i = 0 to fn.nparams do let a = slot i in pr "\t%s\tR%d, %s\n" mov i a done;
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

let startup m units =
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
  pr "\tTEXT\tml_raise(SB), %s\n\t%s\tml_handler(SB), R%d\n" m.frame mov t;
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
  func m out { name = "ml_program"; nparams = 0; nslots = 1; code };
  (* the curry functions, once for all the units (a function of one
   * parameter more than the registers hold is refused where it is) *)
  List.iter (func m out) (Lower.curry_funcs (m.nregs - 1));
  words m out "ml_units" (string_of_int (List.length units) :: List.map (fun u -> Lower.mangle u ^ ".Roots(SB)") units);
  Buffer.contents out
