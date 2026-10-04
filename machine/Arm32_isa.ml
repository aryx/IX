(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ARM's 32-bit instructions (A32, ARM mode): a word decoded once into
 * a variant, and printed as binutils' objdump prints it (the decoder's
 * test: every word the corpus runs, machine/tests/words_arm.txt,
 * printed the same by both; plan_arm.md, phase 1).
 *
 *   e0823103   Dp {op = ADD; rd = 3; rn = 2; op2 = Sreg (3, By_imm (LSL, 2))}
 *              add  r3, r2, r3, lsl #2
 *   e59f0414   Mem {load; size = Word; rd = 0; rn = 15; offset = Off_imm 1044; ...}
 *              ldr  r0, [pc, #1044]
 *   e8bd8010   Block {load; rn = 13; writeback; mode = IA; regs = r4, pc}
 *              pop  {r4, pc}
 *   1a000003   Branch {cond = NE; link = false; offset = 12}
 *              bne  0x14            (at address 0: the pc reads 8 ahead)
 *
 * A word's class is in bits 27-25 (data processing, loads and stores,
 * block transfers, branches, coprocessor and svc); inside class 000,
 * bits 7-4 separate multiplies (1001), halfword and signed transfers
 * (1xx1), and the miscellaneous instructions (bx, clz). A word no case
 * matches is [Undefined]: the corpus decides what is decoded
 * (plan_arm.md's principles).
 *
 * References: ARM Architecture Reference Manual, ARMv7-A and ARMv7-R
 * edition (ARM DDI 0406; from memory), the encodings; binutils'
 * objdump 2.42, run, the printed form. *)

(* (No Arm32_isa.mli: the module is the instruction set as types, the
 * ISA; decoding and running the instructions is Arm32.) *)

type reg = int                (* 0-15: r0-r9, sl, fp, ip, sp, lr, pc *)

type cond = EQ | NE | CS | CC | MI | PL | VS | VC | HI | LS | GE | LT | GT | LE | AL

type dp_op = AND | EOR | SUB | RSB | ADD | ADC | SBC | RSC | TST | TEQ | CMP | CMN | ORR | MOV | BIC | MVN

type shift = LSL | LSR | ASR | ROR

(* how a register operand is shifted: an amount of 1-32 (LSR and ASR
 * #32 are encoded as 0), by a register, or RRX (ROR #0) *)
type shifted = No_shift | By_imm of shift * int | By_reg of shift * reg | Rrx

(* the second operand: an 8-bit value rotated right by an even amount,
 * or a register, shifted *)
type operand = Imm of { imm8 : int; rot : int } | Sreg of reg * shifted

type size = Word | Byte | Half | Sbyte | Shalf | Dword

type offset = Off_imm of int | Off_reg of reg * shifted

type index = Pre | Post

type mode = IA | IB | DA | DB

type rev = Rev32 | Rev16 | Revsh

type mulhalf = Smla | Smul | Smlaw | Smulw | Smlal

type vop = Vmla | Vmls | Vnmla | Vnmls | Vmul | Vnmul | Vadd | Vsub | Vdiv

type vunop = Vmov_reg | Vabs | Vneg | Vsqrt

(* between precisions; from a 32-bit integer; to one ([round_zero]:
 * vcvt, toward zero; else vcvtr, FPSCR's mode) *)
type vconv = Cvt_precision | Cvt_of_int of { signed : bool } | Cvt_to_int of { signed : bool; round_zero : bool }

type t =
  | Dp of { cond : cond; op : dp_op; s : bool; rd : reg; rn : reg; op2 : operand }
  | Mul of { cond : cond; s : bool; rd : reg; rm : reg; rs : reg; acc : reg option }
  | Mull of { cond : cond; s : bool; signed : bool; acc : bool; rdlo : reg; rdhi : reg; rm : reg; rs : reg }
  (* up: the offset added; writeback with Pre: "!"; Post always writes
   * back, and with the W bit set is the unprivileged access (ldrt,
   * strbt: [user]) *)
  | Mem of { cond : cond; load : bool; size : size; rd : reg; rn : reg; offset : offset; up : bool; index : index; writeback : bool; user : bool }
  | Block of { cond : cond; load : bool; rn : reg; writeback : bool; mode : mode; regs : int; psr : bool }
  | Branch of { cond : cond; link : bool; offset : int }
  | Bx of { cond : cond; link : bool; rm : reg }
  | Clz of { cond : cond; rd : reg; rm : reg }
  (* rev, rev16, revsh (ARMv6) *)
  | Rev of { cond : cond; kind : rev; rd : reg; rm : reg }
  (* ARMv5TE's halfword multiplies: [x], [y] the top halves of rm and
   * rs; rn the accumulator (smla, smlaw), or RdLo with rd RdHi (smlal) *)
  | Mulhalf of { cond : cond; op : mulhalf; x : bool; y : bool; rd : reg; rn : reg; rm : reg; rs : reg }
  (* the status register, CPSR; [fields]: the mask, bits f s x c *)
  (* the CPSR, or the mode's SPSR ([spsr]) *)
  | Mrs of { cond : cond; rd : reg; spsr : bool }
  | Msr of { cond : cond; spsr : bool; fields : int; src : operand }
  (* mcr ([load] false), mrc: a coprocessor's register (CP15's, the
   * system's), cp <> 10, 11 *)
  | Coproc of { cond : cond; load : bool; cp : int; opc1 : int; crn : int; crm : int; opc2 : int; rd : reg }
  (* mcrr, mrrc: two registers (the ARM1176's cache range operations) *)
  | Coproc2 of { cond : cond; load : bool; cp : int; opc1 : int; crm : int; rd : reg; rd2 : reg }
  (* sxtb sxth uxtb uxth, and with an addend (rn <> 15) sxtab...:
   * rm rotated right by 8 * rot, a byte or a half extended *)
  | Extend of { cond : cond; signed : bool; half : bool; rd : reg; rn : reg; rm : reg; rot : int }
  (* 0 nop, 1 yield, 2 wfe, 3 wfi, 4 sev *)
  | Hint of { cond : cond; hint : int }
  | Swp of { cond : cond; byte : bool; rd : reg; rm : reg; rn : reg }
  (* ldrex, strex: the exclusive monitor is the state's *)
  | Ldrex of { cond : cond; rd : reg; rn : reg }
  | Strex of { cond : cond; rd : reg; rm : reg; rn : reg }
  | Clrex
  (* dsb (4), dmb (5), isb (6), the full system's: no effect here *)
  | Barrier of { kind : int }
  (* cpsie, cpsid, cps: the A, I, F masks cleared ([enable]) or set,
   * and the mode changed ([mode]); a no-op in user mode *)
  | Cps of { imod : int; a : bool; i : bool; f : bool; mode : int option }
  (* VFP's control registers (0 FPSID, 1 FPSCR, 8 FPEXC), and its double
   * registers' loads and stores: what 9pi's kernel uses *)
  | Vmrs of { cond : cond; reg : int; rd : reg }
  | Vmsr of { cond : cond; reg : int; rd : reg }
  (* VFP: a register's number, s0-s31 or d0-d15 by [double] *)
  | Vldst of { cond : cond; load : bool; double : bool; v : int; rn : reg; offset : int }
  (* vldm, vstm, vpush, vpop: [count] registers from [first]; [before]:
   * decrement before (db), else increment after (ia) *)
  | Vblock of { cond : cond; load : bool; double : bool; rn : reg; before : bool; writeback : bool; first : int; count : int }
  (* vmov between a single and a core register, a double and two *)
  | Vmov_single of { cond : cond; to_core : bool; s : int; rt : reg }
  | Vmov_double of { cond : cond; to_core : bool; d : int; rt : reg; rt2 : reg }
  | Vop of { cond : cond; op : vop; double : bool; d : int; n : int; m : int }
  | Vunop of { cond : cond; op : vunop; double : bool; d : int; m : int }
  (* vcmp, vcmpe ([e]): with m, or with 0.0 *)
  | Vcmp of { cond : cond; e : bool; double : bool; d : int; m : int option }
  (* [double]: the instruction's size field (the source's precision for
   * a conversion to integer or between precisions, the destination's
   * for one from integer) *)
  | Vcvt of { cond : cond; conv : vconv; double : bool; d : int; m : int }
  | Svc of { cond : cond; imm : int }
  | Undefined of int
