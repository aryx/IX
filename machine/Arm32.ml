(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Arm32.mli *)

open Arm32_isa

let field = Bits.field
let bit = Bits.bit

let conds = [| EQ; NE; CS; CC; MI; PL; VS; VC; HI; LS; GE; LT; GT; LE; AL |]
let dp_ops = [| AND; EOR; SUB; RSB; ADD; ADC; SBC; RSC; TST; TEQ; CMP; CMN; ORR; MOV; BIC; MVN |]
let shifts = [| LSL; LSR; ASR; ROR |]

(*****************************************************************************)
(* Decoding *)
(*****************************************************************************)

(* a register shifted by an immediate (bit 4 = 0) or by a register *)
let shifted w =
  let rm = field w 0 4 and sh = shifts.(field w 5 2) in
  if bit w 4 then Sreg (rm, By_reg (sh, field w 8 4))
  else
    let n = field w 7 5 in
    Sreg (rm, match sh, n with
      | LSL, 0 -> No_shift
      | (LSR | ASR), 0 -> By_imm (sh, 32)
      | ROR, 0 -> Rrx
      | _ -> By_imm (sh, n))

let offset_of = function Sreg (rm, s) -> Off_reg (rm, s) | Imm _ -> assert false

(* VFP's registers: 4 bits in the word and one more, the high bit of a
 * double's number (d0-d31; d0-d15 here), the low bit of a single's *)
let vreg ~double w ~at ~extra = if double then (field w extra 1 lsl 4) lor field w at 4 else (field w at 4 lsl 1) lor field w extra 1

(* the loads and stores of the VFP registers (coprocessors 10 and 11):
 * vldr, vstr; vldm, vstm (increment after, or decrement before with
 * writeback); vmov of a double from or to two core registers *)
let vfp_transfer w cond =
  let double = bit w 8 and rn = field w 16 4 in
  let vd = vreg ~double w ~at:12 ~extra:22 in
  let p = bit w 24 and u = bit w 23 and wb = bit w 21 and load = bit w 20 in
  if field w 21 4 = 2 then
    if double && field w 6 2 = 0 && bit w 4 then
      Vmov_double { cond; to_core = load; d = vreg ~double w ~at:0 ~extra:5; rt = field w 12 4; rt2 = rn }
    else Undefined w
  else if p && not wb then
    let off = field w 0 8 * 4 in
    Vldst { cond; load; double; v = vd; rn; offset = (if u then off else - off) }
  else if (u && not p) || (p && (not u) && wb) then
    let imm = field w 0 8 in
    let count = if double then imm / 2 else imm in
    if count = 0 || (double && imm land 1 = 1) || vd + count > (if double then 16 else 32) || rn = 15 then Undefined w
    else Vblock { cond; load; double; rn; before = p; writeback = wb; first = vd; count }
  else Undefined w

(* the VFP's data processing (bit 4 clear), and vmov of a single from or
 * to a core register *)
let vfp_data w cond =
  let double = bit w 8 in
  let d = vreg ~double w ~at:12 ~extra:22 and n = vreg ~double w ~at:16 ~extra:7 and m = vreg ~double w ~at:0 ~extra:5 in
  let op6 = bit w 6 in
  if bit w 4 then
    if field w 21 3 = 0 && not double && field w 0 7 = 0x10 then
      Vmov_single { cond; to_core = bit w 20; s = vreg ~double:false w ~at:16 ~extra:7; rt = field w 12 4 }
    else Undefined w
  else
    let vop op = Vop { cond; op; double; d; n; m } in
    match bit w 23, bit w 21, bit w 20 with
    | false, false, false -> vop (if op6 then Vmls else Vmla)
    | false, false, true -> vop (if op6 then Vnmla else Vnmls)
    | false, true, false -> vop (if op6 then Vnmul else Vmul)
    | false, true, true -> vop (if op6 then Vsub else Vadd)
    | true, false, false when not op6 -> vop Vdiv
    | true, true, true when op6 ->
        (* the others, by the Vn field and bit 7 *)
        let b7 = bit w 7 in
        let single_of at extra = vreg ~double:false w ~at ~extra in
        (match field w 16 4 with
         | 0 -> Vunop { cond; op = (if b7 then Vabs else Vmov_reg); double; d; m }
         | 1 -> Vunop { cond; op = (if b7 then Vsqrt else Vneg); double; d; m }
         | 4 -> Vcmp { cond; e = b7; double; d; m = Some m }
         | 5 when field w 0 4 = 0 && not (bit w 5) -> Vcmp { cond; e = b7; double; d; m = None }
         | 7 when b7 ->
             (* the destination the other precision *)
             let d = vreg ~double:(not double) w ~at:12 ~extra:22 in
             Vcvt { cond; conv = Cvt_precision; double; d; m }
         | 8 -> Vcvt { cond; conv = Cvt_of_int { signed = b7 }; double; d; m = single_of 0 5 }
         | (12 | 13) as k ->
             Vcvt { cond; conv = Cvt_to_int { signed = k = 13; round_zero = b7 }; double; d = single_of 12 22; m }
         | _ -> Undefined w)
    | _ -> Undefined w

let decode w =
  let cond_bits = field w 28 4 in
  if cond_bits = 15 then
    (* the unconditional space: clrex and the barriers (full system) *)
    if w = Bits.mask32 ((0xf57 lsl 20) lor 0xff01f) then Clrex
    else if field w 8 24 = 0xf57ff0 && field w 0 4 = 15 && field w 4 4 >= 4 && field w 4 4 <= 6 then Barrier { kind = field w 4 4 }
    (* claude: cps (ARMv6), a bare-metal Pi1 kernel's cpsie and cpsid:
     * imod 2 enables, 3 disables; M, a mode *)
    else if field w 20 8 = 0x10 && not (bit w 16) && field w 9 7 = 0 && not (bit w 5)
            && (field w 18 2 >= 2 || (field w 18 2 = 0 && bit w 17)) && (bit w 17 || field w 0 5 = 0)
            && (field w 18 2 <> 0 || field w 6 3 = 0) then
      Cps { imod = field w 18 2; a = bit w 8; i = bit w 7; f = bit w 6; mode = (if bit w 17 then Some (field w 0 5) else None) }
    else Undefined w
  else
    let cond = conds.(cond_bits) in
    let rn = field w 16 4 and rd = field w 12 4 in
    match field w 25 3 with
    | 0 when field w 4 4 = 0b1001 && field w 22 3 = 0 ->
        Mul { cond; s = bit w 20; rd = rn; rm = field w 0 4; rs = field w 8 4; acc = (if bit w 21 then Some rd else None) }
    | 0 when field w 4 4 = 0b1001 && field w 23 2 = 1 ->
        Mull { cond; s = bit w 20; signed = bit w 22; acc = bit w 21; rdhi = rn; rdlo = rd; rm = field w 0 4; rs = field w 8 4 }
    (* swp, and ARMv6's exclusive word accesses *)
    | 0 when field w 4 4 = 0b1001 && field w 23 2 = 2 && field w 20 2 = 0 && field w 8 4 = 0 ->
        Swp { cond; byte = bit w 22; rd; rm = field w 0 4; rn }
    | 0 when field w 4 4 = 0b1001 && field w 21 4 = 0b1100 && field w 8 4 = 15 ->
        if bit w 20 then (if field w 0 4 = 15 then Ldrex { cond; rd; rn } else Undefined w)
        else Strex { cond; rd; rm = field w 0 4; rn }
    | 0 when field w 4 4 = 0b1001 -> Undefined w
    | 0 when bit w 7 && bit w 4 ->
        (* halfwords, signed bytes, doublewords *)
        let load = bit w 20 in
        let size = match field w 5 2, load with
          | 1, _ -> Some Half
          | 2, true -> Some Sbyte
          | 3, true -> Some Shalf
          | (2 | 3), false -> Some Dword
          | _ -> None in
        (match size with
         | None -> Undefined w
         (* a register offset leaves bits 11-8 zero *)
         | Some _ when (not (bit w 22)) && field w 8 4 <> 0 -> Undefined w
         | Some size ->
             let offset = if bit w 22 then Off_imm ((field w 8 4 lsl 4) lor field w 0 4) else Off_reg (field w 0 4, No_shift) in
             (* ldrd and strd: bit 5 says which (strd when set) *)
             let load = if size = Dword then not (bit w 5) else load in
             Mem { cond; load; size; rd; rn; offset; up = bit w 23; index = (if bit w 24 then Pre else Post);
                   writeback = bit w 24 && bit w 21; user = (not (bit w 24)) && bit w 21 && size <> Dword })
    | 0 when field w 23 2 = 2 && not (bit w 20) ->
        (* miscellaneous: bx, blx, clz (TST..CMN without S) *)
        if field w 4 4 = 1 && field w 21 2 = 1 && field w 8 12 = 0xfff then Bx { cond; link = false; rm = field w 0 4 }
        else if field w 4 4 = 3 && field w 21 2 = 1 && field w 8 12 = 0xfff then Bx { cond; link = true; rm = field w 0 4 }
        else if field w 4 4 = 1 && field w 21 2 = 3 && field w 16 4 = 15 && field w 8 4 = 15 then Clz { cond; rd; rm = field w 0 4 }
        (* the status register: CPSR only, SPSR (bit 22) is privileged *)
        else if (not (bit w 21)) && field w 16 4 = 15 && field w 0 12 = 0 then Mrs { cond; rd; spsr = bit w 22 }
        else if bit w 21 && rd = 15 && field w 4 8 = 0 then Msr { cond; spsr = bit w 22; fields = rn; src = Sreg (field w 0 4, No_shift) }
        (* claude: ARMv5TE's halfword multiplies (GCC emits smlabb) *)
        else if bit w 7 && not (bit w 4) then
          let x = bit w 5 and y = bit w 6 and rm = field w 0 4 and rs = field w 8 4 in
          let mh op = Mulhalf { cond; op; x; y; rd = rn; rn = rd; rm; rs } in
          (match field w 21 2 with
           | 0 -> mh Smla
           | 1 when not x -> mh Smlaw
           | 1 when rd = 0 -> mh Smulw
           | 2 -> mh Smlal
           | 3 when rd = 0 -> mh Smul
           | _ -> Undefined w)
        else Undefined w
    | 0 -> Dp { cond; op = dp_ops.(field w 21 4); s = bit w 20; rd; rn; op2 = shifted w }
    (* the hints: msr with no field (nop, yield, wfe, wfi, sev) *)
    | 1 when field w 20 8 = 0x32 && rn = 0 && rd = 15 && field w 8 4 = 0 && field w 0 8 <= 4 -> Hint { cond; hint = field w 0 8 }
    | 1 when field w 23 2 = 2 && field w 20 2 = 2 && rd = 15 && rn <> 0 ->
        Msr { cond; spsr = bit w 22; fields = rn; src = Imm { imm8 = field w 0 8; rot = field w 8 4 * 2 } }
    | 1 when field w 23 2 = 2 && not (bit w 20) -> Undefined w
    | 1 -> Dp { cond; op = dp_ops.(field w 21 4); s = bit w 20; rd; rn; op2 = Imm { imm8 = field w 0 8; rot = field w 8 4 * 2 } }
    (* claude: rev, rev16, revsh *)
    | 3 when field w 16 4 = 15 && field w 8 4 = 15 && ((field w 20 8 = 0x6b && (field w 4 4 = 3 || field w 4 4 = 11)) || (field w 20 8 = 0x6f && field w 4 4 = 11)) ->
        Rev { cond; kind = (if field w 20 8 = 0x6f then Revsh else if field w 4 4 = 3 then Rev32 else Rev16); rd; rm = field w 0 4 }
    (* ARMv6's extends, sxtb uxth sxtah...: Rn 15 for none (not the
     * dual-byte forms, 16) *)
    | 3 when bit w 4 && field w 23 2 = 1 && field w 4 4 = 7 && field w 8 2 = 0 && field w 20 2 >= 2 ->
        Extend { cond; signed = not (bit w 22); half = bit w 20; rd; rn; rm = field w 0 4; rot = field w 10 2 }
    | (2 | 3) as c ->
        if c = 3 && bit w 4 then Undefined w
        else
          let offset = if c = 2 then Off_imm (field w 0 12) else offset_of (shifted w) in
          let pre = bit w 24 in
          Mem { cond; load = bit w 20; size = (if bit w 22 then Byte else Word); rd; rn; offset; up = bit w 23;
                index = (if pre then Pre else Post); writeback = pre && bit w 21; user = (not pre) && bit w 21 }
    | 4 ->
        let mode = match bit w 24, bit w 23 with false, true -> IA | true, true -> IB | false, false -> DA | true, false -> DB in
        Block { cond; load = bit w 20; rn; writeback = bit w 21; mode; regs = field w 0 16; psr = bit w 22 }
    | 5 -> Branch { cond; link = bit w 24; offset = Bits.sign_extend 24 (field w 0 24) * 4 }
    | 7 when bit w 24 -> Svc { cond; imm = field w 0 24 }
    (* VFP: coprocessors 10 (singles) and 11 (doubles) *)
    | 6 when field w 9 3 = 5 -> vfp_transfer w cond
    | 6 when field w 21 4 = 2 && field w 9 3 = 7 ->
        Coproc2 { cond; load = bit w 20; cp = field w 8 4; opc1 = field w 4 4; crm = field w 0 4; rd; rd2 = rn }
    (* vmrs, vmsr: FPSID, FPSCR, FPEXC *)
    | 7 when field w 21 3 = 7 && field w 0 12 = 0xa10 && (rn = 0 || rn = 1 || rn = 8) ->
        if bit w 20 then Vmrs { cond; reg = rn; rd } else Vmsr { cond; reg = rn; rd }
    | 7 when field w 9 3 = 5 && not (bit w 24) -> vfp_data w cond
    (* mcr, mrc to the system's coprocessors, 14 and 15 (10 and 11 are
     * VFP's; the others the Pi's cores lack) *)
    | 7 when bit w 4 && field w 9 3 = 7 ->
        Coproc { cond; load = bit w 20; cp = field w 8 4; opc1 = field w 21 3; crn = rn; crm = field w 0 4; opc2 = field w 5 3; rd }
    | _ -> Undefined w

(* (used by the printer too: compat/Show_arm32) *)
let imm_value ~imm8 ~rot = Bits.ror32 imm8 rot


(*****************************************************************************)
(* Execution *)
(*****************************************************************************)

type state = {
  r : int array;
  mutable n : bool;
  mutable z : bool;
  mutable c : bool;
  mutable v : bool;
  mutable next : int;
  mem : Memory.t;
  (* the privileged state (a system's; user mode keeps usr and no MMU) *)
  mutable mode : int;
  mutable a_off : bool;
  mutable i_off : bool;
  mutable f_off : bool;
  banked : int array;
  fiq_banked : int array;
  spsr : int array;
  mutable mmu : bool;
  mutable translate : int -> int -> int;
  mutable coproc : state -> t -> unit;
  mutable vectors : int;
  (* the exclusive monitor (ldrex, strex): the address, -1 open *)
  mutable exclusive : int;
  (* VFP: usable when the system grants it (CPACR: [vfp_ok]); d0-d31
   * as 64 words, FPSCR, FPEXC, FPSID *)
  mutable vfp_ok : bool;
  vfp : int array;
  mutable fpscr : int;
  mutable fpexc : int;
  mutable fpsid : int;
}

exception Unimplemented of int * int
exception Abort of int * int

let create mem =
  { r = Array.make 16 0; n = false; z = false; c = false; v = false; next = 0; mem;
    mode = 0x10; a_off = false; i_off = false; f_off = false;
    banked = Array.make 12 0; fiq_banked = Array.make 10 0; spsr = Array.make 6 0;
    mmu = false; translate = (fun a _ -> a); coproc = (fun st _ -> raise (Unimplemented (0, st.r.(15) - 8))); vectors = 0;
    exclusive = -1; vfp_ok = false; vfp = Array.make 64 0; fpscr = 0; fpexc = 0; fpsid = 0x410120b5 }

(*****************************************************************************)
(* The privileged state: modes, banks, the CPSR, exceptions *)
(*****************************************************************************)

(* the modes' banks of r13 and r14: usr and sys share the first *)
let bank_of = function 0x13 -> 1 | 0x17 -> 2 | 0x1b -> 3 | 0x12 -> 4 | 0x11 -> 5 | _ -> 0

(* a mode change: the outgoing mode's r13, r14 (and r8-r12, for FIQ)
 * saved, the incoming one's put in their place *)
let set_mode st m =
  let old_b = bank_of st.mode and new_b = bank_of m in
  if old_b <> new_b then begin
    st.banked.(2 * old_b) <- st.r.(13); st.banked.((2 * old_b) + 1) <- st.r.(14);
    st.r.(13) <- st.banked.(2 * new_b); st.r.(14) <- st.banked.((2 * new_b) + 1);
    if (old_b = 5) <> (new_b = 5) then begin
      let save, load = if new_b = 5 then 0, 5 else 5, 0 in
      for k = 0 to 4 do st.fiq_banked.(save + k) <- st.r.(8 + k); st.r.(8 + k) <- st.fiq_banked.(load + k) done
    end
  end;
  st.mode <- m

let cpsr st =
  let b f k = if f then 1 lsl k else 0 in
  b st.n 31 lor b st.z 30 lor b st.c 29 lor b st.v 28 lor b st.a_off 8 lor b st.i_off 7 lor b st.f_off 6 lor st.mode

(* the CPSR written, its fields f s x c as masked: the flags always; the
 * masks and the mode only when privileged *)
let write_cpsr st v fields =
  if fields land 8 <> 0 then begin
    st.n <- (v lsr 31) land 1 = 1; st.z <- (v lsr 30) land 1 = 1;
    st.c <- (v lsr 29) land 1 = 1; st.v <- (v lsr 28) land 1 = 1
  end;
  if st.mode <> 0x10 then begin
    if fields land 2 <> 0 then st.a_off <- (v lsr 8) land 1 = 1;
    if fields land 1 <> 0 then begin
      st.i_off <- (v lsr 7) land 1 = 1; st.f_off <- (v lsr 6) land 1 = 1;
      (* a mode this CPU lacks (monitor, 0x16, without the Security
       * Extensions' secure state: QEMU's Non-secure Pi) leaves the mode
       * as it was, the masks written (xv6's tvinit counts on it) *)
      match v land 0x1f with
      | (0x10 | 0x11 | 0x12 | 0x13 | 0x17 | 0x1b | 0x1f) as m -> set_mode st m
      | _ -> ()
    end
  end

(* an exception return: the CPSR from the mode's SPSR *)
let restore_spsr st = let b = bank_of st.mode in if b <> 0 then write_cpsr st st.spsr.(b) 0xf

type exn_kind = Reset | Undefined_instruction | Supervisor_call | Prefetch_abort | Data_abort | Irq | Fiq

(* an exception taken: the CPSR into the new mode's SPSR, the return
 * address into its lr, interrupts masked, the vector *)
let take st kind ~ret =
  let m, off = match kind with
    | Reset -> 0x13, 0 | Undefined_instruction -> 0x1b, 4 | Supervisor_call -> 0x13, 8
    | Prefetch_abort -> 0x17, 0xc | Data_abort -> 0x17, 0x10 | Irq -> 0x12, 0x18 | Fiq -> 0x11, 0x1c in
  let saved = cpsr st in
  set_mode st m;
  st.spsr.(bank_of m) <- saved;
  st.r.(14) <- Bits.mask32 ret;
  st.i_off <- true;
  (match kind with Reset | Fiq -> st.f_off <- true | _ -> ());
  (match kind with Undefined_instruction | Supervisor_call -> () | _ -> st.a_off <- true);
  st.next <- Bits.mask32 (st.vectors + off)

(* an address through the MMU, when on: bit 0 of [w] a write, bit 1 as
 * user (ldrt) *)
let[@inline] phys st a w = if st.mmu then st.translate a w else a

(* a VFP instruction allowed: VFP granted; a control register (FPSID,
 * FPEXC) privileged, the rest with FPEXC.EN set; else undefined *)
(* the VFP's registers as floats: a single is one word of [vfp], a
 * double two (d_n: words 2n, 2n+1, low first) *)
let get_s st i = Int32.float_of_bits (Int32.of_int st.vfp.(i))
let set_s st i f = st.vfp.(i) <- Bits.mask32 (Int32.to_int (Int32.bits_of_float f))
let get_d st i =
  Int64.float_of_bits (Int64.logor (Int64.shift_left (Int64.of_int st.vfp.((2 * i) + 1)) 32)
                         (Int64.logand (Int64.of_int st.vfp.(2 * i)) 0xffffffffL))
let set_d st i f =
  let b = Int64.bits_of_float f in
  st.vfp.(2 * i) <- Bits.mask32 (Int64.to_int (Int64.logand b 0xffffffffL));
  st.vfp.((2 * i) + 1) <- Bits.mask32 (Int64.to_int (Int64.shift_right_logical b 32))
let get_v st double i = if double then get_d st i else get_s st i
let set_v st double i f = if double then set_d st i f else set_s st i f

(* a result in single precision: computed in double, then rounded once
 * (exact for +, -, *, /, sqrt: a double has more than twice a single's
 * bits) *)
let round_to double f = if double then f else Int32.float_of_bits (Int32.bits_of_float f)

(* to a 32-bit integer: saturated, NaN 0; toward zero, or to nearest
 * with ties to even (vcvtr in FPSCR's default mode) *)
let to_int ~signed ~round_zero f =
  let r = if round_zero then Float.trunc f
    else let t = Float.round f in if Float.abs (f -. Float.trunc f) = 0.5 then 2. *. Float.round (f /. 2.) else t in
  let lo, hi = if signed then -2147483648., 2147483647. else 0., 4294967295. in
  if Float.is_nan r then 0 else Bits.mask32 (Int64.to_int (Int64.of_float (Float.min hi (Float.max lo r))))

let vfp_check st ~control addr =
  let ok = st.vfp_ok && (if control then st.mode <> 0x10 else st.fpexc land (1 lsl 30) <> 0) in
  if not ok then raise (Unimplemented (0, addr))

(* the user mode's registers, from a privileged mode (ldm and stm with ^) *)
let get_user st k =
  if (k = 13 || k = 14) && bank_of st.mode <> 0 then st.banked.(k - 13)
  else if k >= 8 && k <= 12 && st.mode = 0x11 then st.fiq_banked.(k - 8)
  else st.r.(k)

let set_user st k v =
  if (k = 13 || k = 14) && bank_of st.mode <> 0 then st.banked.(k - 13) <- v
  else if k >= 8 && k <= 12 && st.mode = 0x11 then st.fiq_banked.(k - 8) <- v
  else st.r.(k) <- v

let cond_passed st = function
  | EQ -> st.z | NE -> not st.z | CS -> st.c | CC -> not st.c | MI -> st.n | PL -> not st.n
  | VS -> st.v | VC -> not st.v | HI -> st.c && not st.z | LS -> (not st.c) || st.z
  | GE -> st.n = st.v | LT -> st.n <> st.v | GT -> (not st.z) && st.n = st.v | LE -> st.z || st.n <> st.v | AL -> true

(* a register written; pc: a jump (ARM state only: bit 0 would be Thumb) *)
let[@inline] set st rd v =
  if rd = 15 then begin
    if v land 1 <> 0 then raise (Unimplemented (v, st.r.(15) - 8)) (* Thumb *)
    else st.next <- Bits.mask32 (v land lnot 3)
  end
  else st.r.(rd) <- v

(* the shifter's carry out, left here by [shift], [shifted_value] and
 * [operand] (returning a pair allocated one per instruction) *)
let carry_out = ref false

(* the shifter: a value, its carry out in [carry_out] *)
let shift st v sh n =
  let bitc k = (v lsr k) land 1 = 1 in
  match sh with
  | LSL ->
      if n = 0 then (carry_out := st.c; v)
      else if n < 32 then (carry_out := bitc (32 - n); Bits.lsl32 v n)
      else (carry_out := (n = 32 && bitc 0); 0)
  | LSR ->
      if n = 0 then (carry_out := st.c; v)
      else if n < 32 then (carry_out := bitc (n - 1); Bits.lsr32 v n)
      else (carry_out := (n = 32 && bitc 31); 0)
  | ASR ->
      if n = 0 then (carry_out := st.c; v)
      else if n < 32 then (carry_out := bitc (n - 1); Bits.asr32 v n)
      else (carry_out := bitc 31; Bits.asr32 v 31)
  | ROR ->
      if n = 0 then (carry_out := st.c; v)
      else
        let k = n land 31 in
        if k = 0 then (carry_out := bitc 31; v) else (carry_out := bitc (k - 1); Bits.ror32 v k)

let shifted_value st rm = function
  | No_shift -> carry_out := st.c; st.r.(rm)
  | By_imm (sh, n) -> shift st st.r.(rm) sh n
  | By_reg (sh, rs) -> shift st st.r.(rm) sh (st.r.(rs) land 0xff)
  | Rrx ->
      let v = st.r.(rm) in
      let r = Bits.mask32 ((if st.c then 1 lsl 31 else 0) lor Bits.lsr32 v 1) in
      carry_out := v land 1 = 1; r

let operand st = function
  | Imm { imm8; rot } ->
      let v = imm_value ~imm8 ~rot in
      carry_out := (if rot = 0 then st.c else (v lsr 31) land 1 = 1); v
  | Sreg (rm, sh) -> shifted_value st rm sh

let set_nz st r = st.n <- (r lsr 31) land 1 = 1; st.z <- r = 0

(* a + b + cin, the flags set when [s] *)
let add_flags st a b cin =
  let r = Bits.add32 a b cin in
  set_nz st r; st.c <- Bits.carry32 a r cin; st.v <- Bits.overflow32 a b r

let not32 b = Bits.mask32 (lnot b)

let execute st ~addr ~svc i =
  st.r.(15) <- Bits.mask32 (addr + 8);
  st.next <- Bits.mask32 (addr + 4);
  match i with
  | Undefined w -> raise (Unimplemented (w, addr))
  | Dp { cond; op; s; rd; rn; op2 } ->
      if cond_passed st cond then begin
        let b = operand st op2 in
        let a = st.r.(rn) in
        (* movs pc, subs pc: a result into pc and the CPSR from the SPSR,
         * the flags not set *)
        let return = s && rd = 15 && (match op with TST | TEQ | CMP | CMN -> false | _ -> true) in
        let s = s && not return in
        let logical r = if s then (set_nz st r; st.c <- !carry_out); set st rd r in
        let arith a b cin = (if s then add_flags st a b cin); set st rd (Bits.add32 a b cin) in
        let cin = if st.c then 1 else 0 in
        (match op with
        | AND -> logical (a land b)
        | EOR -> logical (a lxor b)
        | ORR -> logical (a lor b)
        | BIC -> logical (a land not32 b)
        | MOV -> logical b
        | MVN -> logical (not32 b)
        | ADD -> arith a b 0
        | ADC -> arith a b cin
        | SUB -> arith a (not32 b) 1
        | SBC -> arith a (not32 b) cin
        | RSB -> arith b (not32 a) 1
        | RSC -> arith b (not32 a) cin
        | TST -> set_nz st (a land b); st.c <- !carry_out
        | TEQ -> set_nz st (a lxor b); st.c <- !carry_out
        | CMP -> add_flags st a (not32 b) 1
        | CMN -> add_flags st a b 0);
        if return then restore_spsr st
      end
  | Mul { cond; s; rd; rm; rs; acc } ->
      if cond_passed st cond then begin
        let lo = Bits.mul32 st.r.(rm) st.r.(rs) in
        let r = match acc with Some ra -> Bits.mask32 (lo + st.r.(ra)) | None -> lo in
        if s then set_nz st r;
        set st rd r
      end
  | Mull { cond; s; signed; acc; rdlo; rdhi; rm; rs } ->
      if cond_passed st cond then begin
        let lo, hi = Bits.mul64 ~signed st.r.(rm) st.r.(rs) in
        let lo, hi =
          if acc then
            let l, c, _ = Bits.add_carry lo st.r.(rdlo) 0 in
            l, Bits.mask32 (hi + st.r.(rdhi) + if c then 1 else 0)
          else lo, hi in
        if s then (st.n <- (hi lsr 31) land 1 = 1; st.z <- lo = 0 && hi = 0);
        set st rdlo lo;
        set st rdhi hi
      end
  | Mem { cond; load; size; rd; rn; offset; up; index; writeback; user } ->
      if cond_passed st cond then begin
        let off = match offset with Off_imm n -> n | Off_reg (rm, sh) -> shifted_value st rm sh in
        let base = st.r.(rn) in
        let moved = Bits.mask32 (if up then base + off else base - off) in
        let a = match index with Pre -> moved | Post -> base in
        let m = st.mem in
        (* the accesses first (through the MMU when on), then the base
         * written back, then the register loaded (it wins over the
         * base): an abort leaves the registers as they were *)
        let u = if user then 2 else 0 in
        if load then begin
          let p = phys st a u in
          let v = match size with
            | Word -> Memory.load32 m p
            | Byte -> Memory.load8 m p
            | Half -> Memory.load16 m p
            | Sbyte -> Bits.mask32 (Bits.sign_extend 8 (Memory.load8 m p))
            | Shalf -> Bits.mask32 (Bits.sign_extend 16 (Memory.load16 m p))
            | Dword -> Memory.load32 m p in
          let v2 = if size = Dword then Memory.load32 m (phys st (Bits.mask32 (a + 4)) u) else 0 in
          if (index = Post || writeback) && rn <> 15 then st.r.(rn) <- moved;
          set st rd v;
          if size = Dword then set st (rd + 1) v2
        end
        else begin
          let p = phys st a (1 lor u) in
          let v = if rd = 15 then Bits.mask32 (addr + 8) else st.r.(rd) in
          (match size with
           | Word -> Memory.store32 m p v
           | Byte -> Memory.store8 m p v
           | Half | Sbyte | Shalf -> Memory.store16 m p v
           | Dword -> Memory.store32 m p v; Memory.store32 m (phys st (Bits.mask32 (a + 4)) (1 lor u)) st.r.(rd + 1));
          if (index = Post || writeback) && rn <> 15 then st.r.(rn) <- moved
        end
      end
  | Block { cond; load; rn; writeback; mode; regs; psr } ->
      if cond_passed st cond then begin
        (* with ^: the user mode's registers, or with pc loaded, an
         * exception return *)
        let returning = psr && load && regs land 0x8000 <> 0 in
        let user = psr && not returning in
        let count = let rec go k acc = if k = 16 then acc else go (k + 1) (acc + ((regs lsr k) land 1)) in go 0 0 in
        let base = st.r.(rn) in
        let start = match mode with
          | IA -> base | IB -> base + 4 | DA -> base - (4 * count) + 4 | DB -> base - (4 * count) in
        let final = match mode with IA | IB -> base + (4 * count) | DA | DB -> base - (4 * count) in
        let a = ref (Bits.mask32 start) in
        let loaded = ref [] in
        for k = 0 to 15 do
          if (regs lsr k) land 1 = 1 then begin
            if load then loaded := (k, Memory.load32 st.mem (phys st !a 0)) :: !loaded
            else Memory.store32 st.mem (phys st !a 1) (if user then get_user st k else st.r.(k));
            a := Bits.mask32 (!a + 4)
          end
        done;
        if writeback then st.r.(rn) <- Bits.mask32 final;
        List.iter (fun (k, v) -> if user then set_user st k v else set st k v) (List.rev !loaded);
        if returning then restore_spsr st
      end
  | Branch { cond; link; offset } ->
      if cond_passed st cond then begin
        if link then st.r.(14) <- Bits.mask32 (addr + 4);
        st.next <- Bits.mask32 (addr + 8 + offset)
      end
  | Bx { cond; link; rm } ->
      if cond_passed st cond then begin
        let target = st.r.(rm) in
        if link then st.r.(14) <- Bits.mask32 (addr + 4);
        set st 15 target
      end
  | Clz { cond; rd; rm } ->
      if cond_passed st cond then begin
        let v = st.r.(rm) in
        let rec go k = if k < 0 then 32 else if (v lsr k) land 1 = 1 then 31 - k else go (k - 1) in
        set st rd (go 31)
      end
  (* user mode sees N, Z, C, V and the mode (0x10, usr); it writes
   * only the flags *)
  | Rev { cond; kind; rd; rm } ->
      if cond_passed st cond then begin
        let v = st.r.(rm) in
        let b k = (v lsr (8 * k)) land 0xff in
        set st rd (Bits.mask32 (match kind with
          | Rev32 -> (b 0 lsl 24) lor (b 1 lsl 16) lor (b 2 lsl 8) lor b 3
          | Rev16 -> (b 2 lsl 24) lor (b 3 lsl 16) lor (b 0 lsl 8) lor b 1
          | Revsh -> Bits.sign_extend 16 ((b 0 lsl 8) lor b 1)))
      end
  | Mulhalf { cond; op; x; y; rd; rn; rm; rs } ->
      if cond_passed st cond then begin
        (* in Int64: exact under js_of_ocaml's 32-bit ints too *)
        let half v top = Int64.of_int (Bits.sign_extend 16 ((if top then v lsr 16 else v) land 0xffff)) in
        let s32 v = Int64.of_int32 (Int32.of_int v) in
        let low v = Bits.mask32 (Int64.to_int (Int64.logand v 0xffffffffL)) in
        let p = Int64.mul (half st.r.(rm) x) (half st.r.(rs) y) in
        match op with
        | Smla -> set st rd (low (Int64.add p (s32 st.r.(rn))))
        | Smul -> set st rd (low p)
        | Smlaw | Smulw ->
            let w = Int64.shift_right (Int64.mul (s32 st.r.(rm)) (half st.r.(rs) y)) 16 in
            set st rd (low (if op = Smlaw then Int64.add w (s32 st.r.(rn)) else w))
        | Smlal ->
            let acc = Int64.logor (Int64.shift_left (Int64.of_int st.r.(rd)) 32) (Int64.logand (Int64.of_int st.r.(rn)) 0xffffffffL) in
            let r = Int64.add acc p in
            set st rn (low r);
            set st rd (low (Int64.shift_right_logical r 32))
      end
  | Mrs { cond; rd; spsr } ->
      if cond_passed st cond then set st rd (if spsr then st.spsr.(bank_of st.mode) else cpsr st)
  | Msr { cond; spsr; fields; src } ->
      if cond_passed st cond then begin
        let v = operand st src in
        if spsr then begin
          let b = bank_of st.mode in
          let mask = List.fold_left (fun acc (bit, m) -> if fields land bit <> 0 then acc lor m else acc) 0
                       [ 8, 0xff lsl 24; 4, 0xff lsl 16; 2, 0xff lsl 8; 1, 0xff ] in
          if b <> 0 then st.spsr.(b) <- Bits.mask32 ((st.spsr.(b) land lnot mask) lor (v land mask))
        end
        else write_cpsr st v fields
      end
  | Coproc { cond; _ } | Coproc2 { cond; _ } -> if cond_passed st cond then st.coproc st i
  | Extend { cond; signed; half; rd; rn; rm; rot } ->
      if cond_passed st cond then begin
        let v = Bits.ror32 st.r.(rm) (8 * rot) in
        let v = if half then v land 0xffff else v land 0xff in
        let v = if signed then Bits.mask32 (Bits.sign_extend (if half then 16 else 8) v) else v in
        set st rd (if rn = 15 then v else Bits.mask32 (st.r.(rn) + v))
      end
  | Swp { cond; byte; rd; rm; rn } ->
      if cond_passed st cond then begin
        let p = phys st st.r.(rn) 1 in
        let old = if byte then Memory.load8 st.mem p else Memory.load32 st.mem p in
        if byte then Memory.store8 st.mem p st.r.(rm) else Memory.store32 st.mem p st.r.(rm);
        set st rd old
      end
  | Ldrex { cond; rd; rn } ->
      if cond_passed st cond then begin
        let p = phys st st.r.(rn) 0 in
        let v = Memory.load32 st.mem p in
        st.exclusive <- p; set st rd v
      end
  | Strex { cond; rd; rm; rn } ->
      if cond_passed st cond then begin
        let p = phys st st.r.(rn) 1 in
        if st.exclusive = p then (Memory.store32 st.mem p st.r.(rm); st.r.(rd) <- 0) else st.r.(rd) <- 1;
        st.exclusive <- -1
      end
  | Clrex -> st.exclusive <- -1
  | Barrier _ -> ()
  | Cps { imod; a; i; f; mode } ->
      if st.mode <> 0x10 then begin
        let off = imod = 3 in
        if imod >= 2 then begin
          if a then st.a_off <- off;
          if i then st.i_off <- off;
          if f then st.f_off <- off
        end;
        Option.iter (set_mode st) mode
      end
  (* VFP: when the system grants it; FPSID and FPEXC privileged, the
   * rest only with FPEXC.EN (the lazy switch's trap) *)
  | Vmrs { cond; reg; rd } ->
      if cond_passed st cond then begin
        vfp_check st ~control:(reg <> 1) addr;
        let v = match reg with 0 -> st.fpsid | 1 -> st.fpscr | _ -> st.fpexc in
        if rd = 15 then write_cpsr st v 8 else set st rd v
      end
  | Vmsr { cond; reg; rd } ->
      if cond_passed st cond then begin
        vfp_check st ~control:(reg <> 1) addr;
        let v = st.r.(rd) in
        match reg with 0 -> () | 1 -> st.fpscr <- v | _ -> st.fpexc <- v
      end
  | Vldst { cond; load; double; v; rn; offset } ->
      if cond_passed st cond then begin
        vfp_check st ~control:false addr;
        let base = if rn = 15 then (addr + 8) land lnot 3 else st.r.(rn) in
        let a = Bits.mask32 (base + offset) in
        let words = if double then [ 2 * v; (2 * v) + 1 ] else [ v ] in
        List.iteri (fun k w ->
          let a = Bits.mask32 (a + (4 * k)) in
          if load then st.vfp.(w) <- Memory.load32 st.mem (phys st a 0) else Memory.store32 st.mem (phys st a 1) st.vfp.(w)) words
      end
  | Vblock { cond; load; double; rn; before; writeback; first; count } ->
      if cond_passed st cond then begin
        vfp_check st ~control:false addr;
        let words = if double then 2 * count else count in
        let base = st.r.(rn) in
        let start = if before then Bits.mask32 (base - (4 * words)) else base in
        let first_word = if double then 2 * first else first in
        for k = 0 to words - 1 do
          let a = Bits.mask32 (start + (4 * k)) in
          if load then st.vfp.(first_word + k) <- Memory.load32 st.mem (phys st a 0)
          else Memory.store32 st.mem (phys st a 1) st.vfp.(first_word + k)
        done;
        if writeback then st.r.(rn) <- Bits.mask32 (if before then start else base + (4 * words))
      end
  | Vmov_single { cond; to_core; s; rt } ->
      if cond_passed st cond then begin
        vfp_check st ~control:false addr;
        if to_core then set st rt st.vfp.(s) else st.vfp.(s) <- st.r.(rt)
      end
  | Vmov_double { cond; to_core; d; rt; rt2 } ->
      if cond_passed st cond then begin
        vfp_check st ~control:false addr;
        if to_core then (set st rt st.vfp.(2 * d); set st rt2 st.vfp.((2 * d) + 1))
        else (st.vfp.(2 * d) <- st.r.(rt); st.vfp.((2 * d) + 1) <- st.r.(rt2))
      end
  | Vop { cond; op; double; d; n; m } ->
      if cond_passed st cond then begin
        vfp_check st ~control:false addr;
        let a = get_v st double n and b = get_v st double m and acc = get_v st double d in
        (* the multiply-accumulates: the product rounded, then added,
         * negated as the architecture says (a negated NaN changes sign:
         * vmls is d + -p, not d - p) *)
        let p = round_to double (a *. b) in
        let r = match op with
          | Vmla -> acc +. p | Vmls -> acc +. (-. p) | Vnmla -> (-. acc) +. (-. p) | Vnmls -> (-. acc) +. p
          | Vmul -> a *. b | Vnmul -> -. p | Vadd -> a +. b | Vsub -> a -. b | Vdiv -> a /. b in
        set_v st double d (round_to double r)
      end
  | Vunop { cond; op; double; d; m } ->
      if cond_passed st cond then begin
        vfp_check st ~control:false addr;
        (* the sign bit itself for vabs and vneg: a NaN's too *)
        let top = if double then (2 * m) + 1 else m and dtop = if double then (2 * d) + 1 else d in
        let sign = 1 lsl 31 in
        match op with
        | Vmov_reg | Vabs | Vneg ->
            if double then st.vfp.(2 * d) <- st.vfp.(2 * m);
            let w = st.vfp.(top) in
            st.vfp.(dtop) <- Bits.mask32 (match op with Vabs -> w land lnot sign | Vneg -> w lxor sign | _ -> w)
        | Vsqrt -> set_v st double d (round_to double (Float.sqrt (get_v st double m)))
      end
  | Vcmp { cond; double; d; m; _ } ->
      if cond_passed st cond then begin
        vfp_check st ~control:false addr;
        let a = get_v st double d and b = match m with Some r -> get_v st double r | None -> 0. in
        (* FPSCR's N Z C V: less 1000, equal 0110, greater 0010, unordered 0011 *)
        let nzcv = if Float.is_nan a || Float.is_nan b then 3 else if a < b then 8 else if a = b then 6 else 2 in
        st.fpscr <- Bits.mask32 ((st.fpscr land 0x0fffffff) lor (nzcv lsl 28))
      end
  | Vcvt { cond; conv; double; d; m } ->
      if cond_passed st cond then begin
        vfp_check st ~control:false addr;
        match conv with
        | Cvt_precision -> set_v st (not double) d (round_to (not double) (get_v st double m))
        | Cvt_of_int { signed } ->
            let i = st.vfp.(m) in
            let f = if signed then Int32.to_float (Int32.of_int i) else Int64.to_float (Int64.logand (Int64.of_int i) 0xffffffffL) in
            set_v st double d (round_to double f)
        | Cvt_to_int { signed; round_zero } -> st.vfp.(d) <- to_int ~signed ~round_zero (get_v st double m)
      end
  (* nop and yield do nothing; wfe, wfi, sev are the system's *)
  | Hint { cond; hint } -> if cond_passed st cond && hint >= 2 then st.coproc st i
  | Svc { cond; imm } -> if cond_passed st cond then svc st imm
