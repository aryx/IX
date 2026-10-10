(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A tiny ARM CPU: an interpreter for the arm64 instructions the tiny
 * toolchain's programs execute. The library of two programs:
 * TinyCPUArm, the CPU run as Linux runs a user program (an executable
 * of TinyAssembler's loaded, its system calls answered by the host);
 * and TinyMachinePi, the CPU in the Pi 4 with its devices. mini-5i
 * (machine/) is 5i's twin: every word the toolchains emit, two
 * architectures, a decode cache. This is what is left when the
 * programs run are TinyC's and TinyML's, with goken's libc.
 *
 * Why this and TinyLibCPU, two small CPUs: TinyCPU is a machine
 * designed, every choice ours, with an assembler because nothing else
 * writes its words. This one is a machine inherited, the one in a
 * Pi, a phone and a Mac, so its programs come from a real toolchain
 * and its check is outside it: the same executable gives the same
 * output on the real CPU, under mini-5i and here. Neither has
 * devices: a system call is where both stop. Below them are their
 * machines, TinyMachinePi and TinyMachine, each using its CPU as a
 * library.
 *
 * What makes it small:
 *
 * - {b No assembler, no instruction type.} A word is decoded and run
 *   in one match, group by group as the architecture's manual tables
 *   them: an immediate operand, a branch, a load or a store, registers.
 *   The words are TinyAssembler's.
 * - {b The interpreter runs words.} Memory holds the program's bytes;
 *   each step fetches the word at pc and decodes it, as the hardware
 *   does. No decode cache: mini-5i has one.
 * - {b A subset, counted.} The groups below are the ones the test
 *   programs of TinyC and TinyML execute, goken's libc included (52
 *   mnemonics, plan_tiny_arm64.md), completed where a group's other
 *   forms cost a line. A word outside it stops the program with its
 *   address, so the subset is also a check.
 * - {b A machine changes four things}, the fields of [env]: a load, a
 *   store, an svc, and a word the decoder does not know. TinyCPUArm
 *   gives memory, Linux's calls, and an error; TinyMachinePi gives the
 *   Pi 4's devices behind addresses, the exception taken, and the
 *   system instructions (mrs, msr, eret). What happens between two
 *   instructions (an interrupt) is the loop's that calls [step].
 *
 * How a word is read. Every instruction is 32 bits, and four of them,
 * 28 to 25, say which table of the manual the rest is read by; that
 * is [step]'s outer match:
 *
 *     bits 28-25   the group                             in [step]
 *     1 0 0 x      an immediate operand (add, mov, and,  8 | 9
 *                  a bitfield, adr)
 *     1 0 1 x      branches, and svc                     10 | 11
 *     x 1 x 0      loads and stores                      4 | 6 | 12 | 14
 *     x 1 0 1      registers (add, and, csel, mul, div)  5 | 13
 *     x 1 1 1      floating point and SIMD               not here
 *
 * For example the word d28acf01, the first of the two TinyAssembler
 * writes for MOV $0x12345678, R1:
 *
 *     1  10  100101  00  0101011001111000  00001
 *     sf opc         hw  imm16             rd
 *
 * Bits 28 to 25 are 1001, an immediate operand; 25 to 23 are 101, a
 * move of 16 bits; opc 10 is movz (00 movn, 11 movk); hw 00 puts them
 * at bit 0; sf 1 is all 64 bits. So x1 becomes 0x5678, and the next
 * word, a movk with hw 01, sets its bits 16 to 31 to 0x1234. Most
 * fields are where they are in every group (rd in the low five bits,
 * rn in the next five, sf at the top), which [step] reads once before
 * its match.
 *
 * The subset: add, sub and their flags (cmp, cmn) with an immediate, a
 * shifted or an extended register; the logical ones (and, orr, eor,
 * bic, orn, eon, tst) with a bitmask immediate or a shifted register;
 * movz, movn, movk; the bitfields (sbfm, bfm, ubfm: the shifts by a
 * constant, the extensions, ubfx); the shifts by a register; madd,
 * msub (mul), udiv, sdiv; csel and its three variants; adr, adrp; the
 * loads and stores of 1, 2, 4 and 8 bytes, zero or sign-extended,
 * with a scaled, an unscaled, a pre or post-indexed offset, or a
 * register's, and a pair's (stp, ldp); a literal's load; b, bl, br,
 * blr, ret, b.cond, cbz, cbnz, tbz, tbnz; svc. Left out, against
 * machine/'s Arm64: floating point and SIMD, the exclusive and atomic
 * loads, adc and sbc, ccmp, the multiplies' high halves, clz and the
 * byte reversals, extr.
 *
 * Exercises:
 * - floating point: the registers d0 to d31, fmov, fadd and the
 *   others, the conversions, for TinyML's floats;
 * - a decode cache, machine/'s: decode once per address;
 * - a trace, each instruction's address and word, as mini-5i -t's.
 *
 * Where it stands: the words are TinyAssembler's, from TinyC's and
 * TinyML's assembly; above it TinyCPUArm (Linux's calls) and
 * TinyMachinePi (a board). mini-5i's Arm64 is the same instruction
 * set whole, with Arm32 beside it, and TinyLibCPU is the same file's
 * plan for a machine that needed no manual: reading the two [step]s
 * side by side shows what forty years of compatibility cost in
 * cases.
 *
 * cs-history:
 * The ARM is Acorn's (Sophie Wilson's instruction set, Steve Furber's
 * design; first silicon in 1985), made for the computer after the BBC
 * Micro by a small team that had read the Berkeley RISC papers: few
 * transistors meant little power, which nobody had asked for and
 * which, in telephones, became the reason it is everywhere. Apple,
 * Acorn and VLSI made ARM a company of its own in 1990, for the
 * Newton. The 64-bit
 * architecture, ARMv8, was announced in 2011 and was in a telephone
 * in 2013; it is a new instruction set, not the old one widened.
 *
 * evolution:
 * What arm64 dropped from arm, each visible here by its absence:
 * the condition on every instruction (left on the branch, and on a
 * few selections: csel); the pc as a register any instruction may
 * write; the load and the store of a list of registers (a pair now:
 * stp, ldp); the shifter operand that could itself be a register.
 * What it added: thirty-one registers where there were sixteen, and
 * a register 31 that is zero or the stack pointer according to the
 * instruction ([reg] and [sp]).
 *
 * terminology:
 * AArch64 is the processor's 64-bit state, A64 its instruction set,
 * ARMv8-A the architecture's version that brought them, arm64 what
 * Linux and Apple call the lot. Plan 9 gives a machine a character:
 * 5 is arm (5a, 5c, 5l, and 5i the emulator, whence mini-5i), 7 is
 * arm64 (7a, 7c, 7l).
 *
 * design:
 * A constant in a logical instruction (and, orr, eor) is not a number
 * of 12 bits as add's is, but a pattern in 13: a run of ones, rotated,
 * repeated across the register ([bitmask]). 0x00ff00ff is one;
 * 0x1234 is not, and must be built in a register first. It is the
 * one place
 * where decoding is not reading fields, and the reason TinyAssembler
 * never writes one.
 *
 * References: Arm Architecture Reference Manual for A-profile (ARM DDI
 * 0487; from memory): the encodings, by their tables' groups; machine/
 * in ix, run on the same programs: the behavior. *)

exception Error of string
let error fmt = Printf.ksprintf (fun s -> raise (Error s)) fmt

(*****************************************************************************)
(* The machine *)
(*****************************************************************************)

type machine = {
  x : Bytes.t;                             (* x0 to x30, then sp: 64 bits each *)
  mutable pc : int;
  mutable n : bool; mutable z : bool; mutable c : bool; mutable v : bool;
  mem : Bytes.t;                           (* from address 0 *)
}

let create size =
  { x = Bytes.make (32 * 8) '\000'; pc = 0; n = false; z = false; c = false; v = false; mem = Bytes.make size '\000' }

(* register 31 is the stack pointer or zero: the instruction says *)
let sp m r = Bytes.get_int64_le m.x (8 * r)
let set_sp m r v = Bytes.set_int64_le m.x (8 * r) v
let reg m r = if r = 31 then 0L else sp m r
let set m r v = if r <> 31 then set_sp m r v

let check m a n = if a < 0 || a + n > Bytes.length m.mem then error "segmentation fault at 0x%x (pc 0x%x)" a m.pc

(* [size]: 0 to 3, for 1, 2, 4 and 8 bytes; a load is zero-extended *)
let load m size a =
  check m a (1 lsl size);
  match size with
  | 0 -> Int64.of_int (Bytes.get_uint8 m.mem a)
  | 1 -> Int64.of_int (Bytes.get_uint16_le m.mem a)
  | 2 -> Int64.logand (Int64.of_int32 (Bytes.get_int32_le m.mem a)) 0xffffffffL
  | _ -> Bytes.get_int64_le m.mem a

let store m size a v =
  check m a (1 lsl size);
  match size with
  | 0 -> Bytes.set_uint8 m.mem a (Int64.to_int v land 0xff)
  | 1 -> Bytes.set_uint16_le m.mem a (Int64.to_int v land 0xffff)
  | 2 -> Bytes.set_int32_le m.mem a (Int64.to_int32 v)
  | _ -> Bytes.set_int64_le m.mem a v

(* what the program that runs the CPU decides *)
type env = {
  load : machine -> int -> int -> int64;             (* size, address *)
  store : machine -> int -> int -> int64 -> unit;
  svc : machine -> int -> unit;    (* the svc's number; pc the return address, the hook may change it *)
  undefined : machine -> int -> unit;                (* the word, pc still on it *)
}

(* memory alone, and an unknown word an error *)
let plain ~svc = {
  load; store; svc;
  undefined = (fun m w -> error "unimplemented instruction %08x at 0x%x" w m.pc);
}

(*****************************************************************************)
(* Values: 64 bits or 32, the instruction's top bit says *)
(*****************************************************************************)

let ones n = if n >= 64 then -1L else Int64.pred (Int64.shift_left 1L n)

(* a 32-bit result fills its register zero-extended *)
let trunc sf v = if sf then v else Int64.logand v 0xffffffffL

(* from its low [bits], sign-extended *)
let sext bits v = let k = 64 - bits in Int64.shift_right (Int64.shift_left v k) k

let negative sf v = Int64.compare (if sf then v else sext 32 v) 0L < 0

(* a + b + cin, and the flags when [s]; a and b in the width *)
let add m sf s a b cin =
  let sum = Int64.add (Int64.add a b) cin in
  let r = trunc sf sum in
  if s then begin
    m.n <- negative sf r; m.z <- r = 0L;
    m.c <- (if sf then (let u = Int64.unsigned_compare r a in if cin = 0L then u < 0 else u <= 0)
            else Int64.unsigned_compare sum 0xffffffffL > 0);
    m.v <- negative sf (Int64.logand (Int64.logxor a r) (Int64.logxor b r))
  end;
  r

let sub m sf s a b = add m sf s a (trunc sf (Int64.lognot b)) 1L

(* and (0), orr (1), eor (2), and with the flags (3: ands, tst) *)
let logic m sf op a b =
  let r = match op with 1 -> Int64.logor a b | 2 -> Int64.logxor a b | _ -> Int64.logand a b in
  if op = 3 then (m.n <- negative sf r; m.z <- r = 0L; m.c <- false; m.v <- false);
  r

(* lsl (0), lsr (1), asr (2), ror (3) by n < the width *)
let shift sf v kind n =
  let v = trunc sf v in
  if n = 0 then v
  else trunc sf (match kind with
    | 0 -> Int64.shift_left v n
    | 1 -> Int64.shift_right_logical v n
    | 2 -> Int64.shift_right (if sf then v else sext 32 v) n
    | _ -> Int64.logor (Int64.shift_right_logical v n) (Int64.shift_left v ((if sf then 64 else 32) - n)))

(* a register's low byte, half, word or all of it, zero (0 to 3) or
 * sign-extended (4 to 7): uxtb ... sxtx *)
let extend v option =
  let bits = 8 lsl (option land 3) in
  if option land 4 <> 0 then sext bits v else Int64.logand v (ones bits)

(* the logical immediate: an element of 2 to 64 bits, its low S+1 bits
 * set, rotated right by R, repeated across the register (the manual's
 * DecodeBitMasks); None when the fields name no value *)
let bitmask sf n immr imms =
  let v = (n lsl 6) lor (lnot imms land 0x3f) in
  let rec high k = if k < 0 then -1 else if (v lsr k) land 1 = 1 then k else high (k - 1) in
  let len = high 6 in
  let levels = (1 lsl (max len 0)) - 1 in
  if len < 1 || (n = 1 && not sf) || imms land levels = levels then None
  else
    let s = imms land levels and r = immr land levels and esize = 1 lsl len in
    let elem = ones (s + 1) in
    let elem = if r = 0 then elem else Int64.logand (ones esize) (Int64.logor (Int64.shift_right_logical elem r) (Int64.shift_left elem (esize - r))) in
    let rec rep acc k = if k >= 64 then acc else rep (Int64.logor acc (Int64.shift_left elem k)) (k + esize) in
    Some (trunc sf (rep 0L 0))

(* eq ne, cs cc, mi pl, vs vc, hi ls, ge lt, gt le, al: a test and its
 * opposite by the low bit *)
let passed m cond =
  let r = match cond lsr 1 with
    | 0 -> m.z | 1 -> m.c | 2 -> m.n | 3 -> m.v | 4 -> m.c && not m.z | 5 -> m.n = m.v | 6 -> m.n = m.v && not m.z
    | _ -> true in
  if cond land 1 = 1 && cond < 14 then not r else r

(*****************************************************************************)
(* One step *)
(*****************************************************************************)

exception Undefined

(* the word at pc decoded and run; the fetch is from memory, whatever
 * env's load: code is never a device's. The groups are the manual's,
 * by the word's bits 28 to 25. *)
let step env m =
  let pc = m.pc in
  check m pc 4;
  let w = Int32.to_int (Bytes.get_int32_le m.mem pc) land 0xffffffff in
  let f lo n = (w lsr lo) land ((1 lsl n) - 1) and bit n = (w lsr n) land 1 = 1 in
  let signed lo n = (f lo n lxor (1 lsl (n - 1))) - (1 lsl (n - 1)) in
  let sf = bit 31 and rd = f 0 5 and rn = f 5 5 and rm = f 16 5 in
  let width = if sf then 64 else 32 in
  let branch d = m.pc <- pc + (4 * d) in
  m.pc <- pc + 4;
  try
    match f 25 4 with
    (* an immediate operand *)
    | 8 | 9 ->
        (match f 23 3 with
         | 0 | 1 ->                        (* adr, adrp: an address near pc, or its page *)
             let d = (signed 5 19 lsl 2) lor f 29 2 in
             set m rd (Int64.of_int (if bit 31 then (pc land lnot 0xfff) + (d lsl 12) else pc + d))
         | 2 ->                            (* add, sub, cmp: 12 bits, maybe shifted by 12 *)
             let a = trunc sf (sp m rn) and b = Int64.of_int (f 10 12 lsl (if bit 22 then 12 else 0)) in
             let r = if bit 30 then sub m sf (bit 29) a b else add m sf (bit 29) a b 0L in
             if bit 29 then set m rd r else set_sp m rd r
         | 4 ->                            (* and, orr, eor, tst: a bitmask *)
             (match bitmask sf (f 22 1) (f 16 6) (f 10 6) with
              | None -> raise Undefined
              | Some b ->
                  let r = logic m sf (f 29 2) (trunc sf (reg m rn)) b in
                  if f 29 2 = 3 then set m rd r else set_sp m rd r)
         | 5 ->                            (* movn, movz, movk: 16 bits at 0, 16, 32 or 48 *)
             let at = 16 * f 21 2 in
             let v = Int64.shift_left (Int64.of_int (f 5 16)) at in
             (match f 29 2 with
              | 0 -> set m rd (trunc sf (Int64.lognot v))
              | 2 -> set m rd v
              | 3 -> set m rd (trunc sf (Int64.logor (Int64.logand (reg m rd) (Int64.lognot (Int64.shift_left 0xffffL at))) v))
              | _ -> raise Undefined)
         | 6 ->                            (* sbfm, bfm, ubfm: a field of rn, moved *)
             let r = f 16 6 and s = f 10 6 and src = trunc sf (reg m rn) in
             (* bits s to r of rn to the bottom; or, when s < r, its low
              * s+1 bits up to width - r: lsl, lsr, asr, sxtw, ubfx are these *)
             let len, bits, at = if s >= r then s - r + 1, Int64.shift_right_logical src r, 0 else s + 1, src, width - r in
             let field = Int64.shift_left (Int64.logand bits (ones len)) at in
             set m rd (trunc sf (match f 29 2 with
               | 0 -> sext (at + len) field
               | 1 -> Int64.logor (Int64.logand (reg m rd) (Int64.lognot (Int64.shift_left (ones len) at))) field
               | 2 -> field
               | _ -> raise Undefined))
         | _ -> raise Undefined)
    (* branches, and the calls of the system *)
    | 10 | 11 ->
        if w land 0x7c000000 = 0x14000000 then begin                 (* b, bl *)
          if bit 31 then set m 30 (Int64.of_int (pc + 4));
          branch (signed 0 26)
        end
        else if w land 0x7e000000 = 0x34000000 then                  (* cbz, cbnz *)
          (if (trunc sf (reg m rd) = 0L) <> bit 24 then branch (signed 5 19))
        else if w land 0x7e000000 = 0x36000000 then                  (* tbz, tbnz: one bit *)
          (let b = (f 31 1 lsl 5) lor f 19 5 in
           if (Int64.logand (Int64.shift_right_logical (reg m rd) b) 1L = 0L) <> bit 24 then branch (signed 5 14))
        else if w land 0xff000010 = 0x54000000 then (if passed m (f 0 4) then branch (signed 5 19))
        else if w land 0xffe0001f = 0xd4000001 then env.svc m (f 5 16)
        else if w land 0xff9ffc1f = 0xd61f0000 && f 21 2 < 3 then begin (* br, blr, ret *)
          let target = Int64.to_int (reg m rn) in
          if f 21 2 = 1 then set m 30 (Int64.of_int (pc + 4));
          m.pc <- target
        end
        else raise Undefined
    (* loads and stores *)
    | 4 | 6 | 12 | 14 ->
        if w land 0x3b000000 = 0x18000000 && not (bit 26) then begin (* a literal near pc *)
          let v = env.load m (if f 30 2 = 1 then 3 else 2) (pc + (4 * signed 5 19)) in
          set m rd (if f 30 2 = 2 then sext 32 v else v)
        end
        else if w land 0x3a000000 = 0x28000000 && not (bit 26) && f 30 2 <> 1 && f 30 2 <> 3 then begin
          (* stp, ldp: two registers, at an offset or pre or post-indexed *)
          let size = if sf then 3 else 2 and base = Int64.to_int (sp m rn) in
          let moved = base + (signed 15 7 lsl size) in
          let a = match f 23 2 with 1 -> base | 2 | 3 -> moved | _ -> raise Undefined in
          if bit 22 then (set m rd (env.load m size a); set m (f 10 5) (env.load m size (a + (1 lsl size))))
          else (env.store m size a (reg m rd); env.store m size (a + (1 lsl size)) (reg m (f 10 5)));
          if f 23 2 <> 2 then set_sp m rn (Int64.of_int moved)
        end
        else if f 27 3 = 7 && not (bit 26) then begin
          let size = f 30 2 and base = Int64.to_int (sp m rn) in
          (* the address, and the base's new value when it is written back *)
          let a, back =
            if bit 24 then base + (f 10 12 lsl size), None                         (* scaled *)
            else if bit 21 then
              (if f 10 2 <> 2 then raise Undefined;                                (* a register's *)
               base + Int64.to_int (Int64.shift_left (extend (reg m rm) (f 13 3)) (if bit 12 then size else 0)), None)
            else match f 10 2 with
              | 0 -> base + signed 12 9, None                                      (* unscaled: ldur, stur *)
              | 1 -> base, Some (base + signed 12 9)                               (* post-indexed *)
              | 3 -> base + signed 12 9, Some (base + signed 12 9)                 (* pre-indexed *)
              | _ -> raise Undefined in
          (match f 22 2 with
           | 0 -> env.store m size a (reg m rd)
           | 1 -> set m rd (env.load m size a)
           | 2 when size < 3 -> set m rd (sext (8 lsl size) (env.load m size a))
           | 3 when size < 2 -> set m rd (trunc false (sext (8 lsl size) (env.load m size a)))
           | _ -> raise Undefined);
          Option.iter (fun b -> set_sp m rn (Int64.of_int b)) back
        end
        else raise Undefined
    (* registers *)
    | 5 | 13 ->
        let a = trunc sf (reg m rn) in
        if not (bit 28) then begin
          if not (bit 24) then begin       (* and, orr, eor, tst; bic, orn, eon: rm shifted, maybe inverted *)
            let b = shift sf (reg m rm) (f 22 2) (f 10 6) in
            set m rd (logic m sf (f 29 2) a (if bit 21 then trunc sf (Int64.lognot b) else b))
          end
          else begin                       (* add, sub, cmp: rm shifted, or extended *)
            let a, b = if bit 21 then trunc sf (sp m rn), trunc sf (Int64.shift_left (extend (reg m rm) (f 13 3)) (f 10 3))
                       else a, shift sf (reg m rm) (f 22 2) (f 10 6) in
            let r = if bit 30 then sub m sf (bit 29) a b else add m sf (bit 29) a b 0L in
            if bit 21 && not (bit 29) then set_sp m rd r else set m rd r
          end
        end
        else begin
          let b = trunc sf (reg m rm) in
          match f 21 4 with
          | 4 when not (bit 29) && not (bit 11) ->   (* csel, csinc, csinv, csneg *)
              set m rd (if passed m (f 12 4) then a
                        else trunc sf (match bit 30, bit 10 with
                          | false, false -> b | false, true -> Int64.succ b
                          | true, false -> Int64.lognot b | true, true -> Int64.neg b))
          | 6 when not (bit 30) ->
              (match f 10 6 with
               | 2 -> set m rd (if b = 0L then 0L else Int64.unsigned_div a b)                        (* udiv *)
               | 3 ->                                                                                    (* sdiv *)
                   let a = if sf then a else sext 32 a and b = if sf then b else sext 32 b in
                   set m rd (if b = 0L then 0L else trunc sf (Int64.div a b))
               | 8 | 9 | 10 | 11 -> set m rd (shift sf a (f 10 2) (Int64.to_int b land (width - 1)))  (* by a register *)
               | _ -> raise Undefined)
          | 8 ->                           (* madd, msub: mul is madd with zero *)
              let p = Int64.mul a b and acc = reg m (f 10 5) in
              set m rd (trunc sf (if bit 15 then Int64.sub acc p else Int64.add acc p))
          | _ -> raise Undefined
        end
    | _ -> raise Undefined
  with Undefined -> m.pc <- pc; env.undefined m w
