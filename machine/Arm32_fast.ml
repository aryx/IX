(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Arm32_fast.mli *)

open Arm32_isa

let on = ref true

(* a register written; pc: a jump (Arm32's set) *)
let set st rd v =
  if rd = 15 then begin
    if v land 1 <> 0 then raise (Arm32.Unimplemented (v, st.r.(15) - 8))
    else st.next <- Bits.mask32 (v land lnot 3)
  end
  else st.r.(rd) <- v

let set_nz st r = st.n <- (r lsr 31) land 1 = 1; st.z <- r = 0

(* Arm32's two local functions of a data-processing instruction, here
 * outside it with what they closed over as arguments *)
let logical st s rd r carry =
  if s then (set_nz st r; st.c <- carry);
  set st rd r

let arith st s rd a b cin =
  let r = Bits.add32 a b cin in
  if s then (set_nz st r; st.c <- Bits.carry32 a r cin; st.v <- Bits.overflow32 a b r);
  set st rd r

let compare st a b cin =
  let r = Bits.add32 a b cin in
  set_nz st r; st.c <- Bits.carry32 a r cin; st.v <- Bits.overflow32 a b r

let not32 b = Bits.mask32 (lnot b)

(* the instruction's work once its second operand is known: [b], and
 * the shifter's carry out *)
let dp st op s rd rn b carry =
  let a = st.r.(rn) in
  match op with
  | AND -> logical st s rd (a land b) carry
  | EOR -> logical st s rd (a lxor b) carry
  | ORR -> logical st s rd (a lor b) carry
  | BIC -> logical st s rd (a land not32 b) carry
  | MOV -> logical st s rd b carry
  | MVN -> logical st s rd (not32 b) carry
  | ADD -> arith st s rd a b 0
  | ADC -> arith st s rd a b (if st.c then 1 else 0)
  | SUB -> arith st s rd a (not32 b) 1
  | SBC -> arith st s rd a (not32 b) (if st.c then 1 else 0)
  | RSB -> arith st s rd b (not32 a) 1
  | RSC -> arith st s rd b (not32 a) (if st.c then 1 else 0)
  | TST -> set_nz st (a land b); st.c <- carry
  | TEQ -> set_nz st (a lxor b); st.c <- carry
  | CMP -> compare st a (not32 b) 1
  | CMN -> compare st a b 0

(* the words of a block load, before any register is written (an abort
 * at one of them leaves the registers as they were) *)
let loaded = Array.make 16 0

let execute st ~addr ~svc i =
  match i with
  (* (not movs pc, subs pc: an exception's return, Arm32's) *)
  | Dp { cond; op; s; rd; rn; op2 } when not (s && rd = 15) ->
      st.r.(15) <- Bits.mask32 (addr + 8);
      st.next <- Bits.mask32 (addr + 4);
      if Arm32.cond_passed st cond then begin
        match op2 with
        | Imm { imm8; rot } ->
            let b = Arm32.imm_value ~imm8 ~rot in
            dp st op s rd rn b (if rot = 0 then st.c else (b lsr 31) land 1 = 1)
        | Sreg (rm, No_shift) -> dp st op s rd rn st.r.(rm) st.c
        | Sreg (rm, By_imm (LSL, n)) when n > 0 && n < 32 ->
            let v = st.r.(rm) in dp st op s rd rn (Bits.lsl32 v n) ((v lsr (32 - n)) land 1 = 1)
        | Sreg (rm, By_imm (LSR, n)) when n > 0 && n < 32 ->
            let v = st.r.(rm) in dp st op s rd rn (Bits.lsr32 v n) ((v lsr (n - 1)) land 1 = 1)
        | Sreg (rm, By_imm (ASR, n)) when n > 0 && n < 32 ->
            let v = st.r.(rm) in dp st op s rd rn (Bits.asr32 v n) ((v lsr (n - 1)) land 1 = 1)
        (* a rotation, a shift by a register or by 32 *)
        | _ -> Arm32.execute st ~addr ~svc i
      end
  | Branch { cond; link; offset } ->
      st.r.(15) <- Bits.mask32 (addr + 8);
      st.next <- Bits.mask32 (addr + 4);
      if Arm32.cond_passed st cond then begin
        if link then st.r.(14) <- Bits.mask32 (addr + 4);
        st.next <- Bits.mask32 (addr + 8 + offset)
      end
  (* (not with ^: the user mode's registers, an exception's return) *)
  | Block { cond; load; rn; writeback; mode; regs; psr = false } ->
      st.r.(15) <- Bits.mask32 (addr + 8);
      st.next <- Bits.mask32 (addr + 4);
      if Arm32.cond_passed st cond then begin
        let count = ref 0 in
        for k = 0 to 15 do count := !count + ((regs lsr k) land 1) done;
        let count = !count in
        let base = st.r.(rn) in
        let start = match mode with
          | IA -> base | IB -> base + 4 | DA -> base - (4 * count) + 4 | DB -> base - (4 * count) in
        let final = match mode with IA | IB -> base + (4 * count) | DA | DB -> base - (4 * count) in
        let a = ref (Bits.mask32 start) and n = ref 0 in
        for k = 0 to 15 do
          if (regs lsr k) land 1 = 1 then begin
            if load then begin
              loaded.(!n) <- Memory.load32 st.mem (if st.mmu then st.translate !a 0 else !a);
              incr n
            end
            else Memory.store32 st.mem (if st.mmu then st.translate !a 1 else !a) st.r.(k);
            a := Bits.mask32 (!a + 4)
          end
        done;
        if writeback then st.r.(rn) <- Bits.mask32 final;
        if load then begin
          n := 0;
          for k = 0 to 15 do
            if (regs lsr k) land 1 = 1 then (set st k loaded.(!n); incr n)
          done
        end
      end
  | _ -> Arm32.execute st ~addr ~svc i
