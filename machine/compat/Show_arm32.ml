(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Show_arm32.mli *)
open Arm32_isa
open Arm32

let reg_name = function
  | 10 -> "sl" | 11 -> "fp" | 12 -> "ip" | 13 -> "sp" | 14 -> "lr" | 15 -> "pc"
  | r -> "r" ^ string_of_int r

let cond_name = function
  | EQ -> "eq" | NE -> "ne" | CS -> "cs" | CC -> "cc" | MI -> "mi" | PL -> "pl" | VS -> "vs" | VC -> "vc"
  | HI -> "hi" | LS -> "ls" | GE -> "ge" | LT -> "lt" | GT -> "gt" | LE -> "le" | AL -> ""

let op_name = function
  | AND -> "and" | EOR -> "eor" | SUB -> "sub" | RSB -> "rsb" | ADD -> "add" | ADC -> "adc" | SBC -> "sbc" | RSC -> "rsc"
  | TST -> "tst" | TEQ -> "teq" | CMP -> "cmp" | CMN -> "cmn" | ORR -> "orr" | MOV -> "mov" | BIC -> "bic" | MVN -> "mvn"

let shift_name = function LSL -> "lsl" | LSR -> "lsr" | ASR -> "asr" | ROR -> "ror"

let shifted_text = function
  | No_shift -> ""
  | By_imm (s, n) -> Printf.sprintf ", %s #%d" (shift_name s) n
  | By_reg (s, r) -> Printf.sprintf ", %s %s" (shift_name s) (reg_name r)
  | Rrx -> ", rrx"

(* the value, unless a smaller rotation encodes it: then objdump shows
 * the encoding, "#imm8, rot" (binutils' arm-dis.c) *)
let operand_text = function
  | Imm { imm8; rot } ->
      let a = imm_value ~imm8 ~rot in
      let rec smallest i = if i >= 32 || Bits.ule32 (Bits.ror32 a (32 - i)) 0xff then i else smallest (i + 2) in
      if smallest 0 <> rot then Printf.sprintf "#%d, %d" imm8 rot
      else Printf.sprintf "#%d" (Bits.signed32 a)
  | Sreg (rm, s) -> reg_name rm ^ shifted_text s

let reglist regs =
  "{" ^ String.concat ", " (List.filter_map (fun r -> if regs land (1 lsl r) <> 0 then Some (reg_name r) else None) (List.init 16 Fun.id)) ^ "}"

let vname double v = (if double then "d" else "s") ^ string_of_int v
let fsize double = if double then ".f64" else ".f32"

let vfp_reg_name = function 0 -> "fpsid" | 1 -> "fpscr" | _ -> "fpexc"

let print ~addr (i : t) =
  let m name args = if args = "" then name else name ^ "\t" ^ args in
  match i with
  | Dp { cond; op = MOV; s; rd; op2 = Sreg (rm, ((By_imm _ | By_reg _ | Rrx) as sh)); _ } ->
      (* a shifted move is its shift's own mnemonic *)
      let name, rest = match sh with
        | By_imm (sh, n) -> shift_name sh, Printf.sprintf "#%d" n
        | By_reg (sh, r) -> shift_name sh, reg_name r
        | Rrx -> "rrx", ""
        | No_shift -> assert false in
      m (name ^ (if s then "s" else "") ^ cond_name cond)
        (reg_name rd ^ ", " ^ reg_name rm ^ (if rest = "" then "" else ", " ^ rest))
  | Dp { cond; op; s; rd; rn; op2 } ->
      let name = op_name op in
      (match op with
       | TST | TEQ | CMP | CMN -> m (name ^ cond_name cond) (reg_name rn ^ ", " ^ operand_text op2)
       | MOV | MVN -> m (name ^ (if s then "s" else "") ^ cond_name cond) (reg_name rd ^ ", " ^ operand_text op2)
       | _ -> m (name ^ (if s then "s" else "") ^ cond_name cond) (reg_name rd ^ ", " ^ reg_name rn ^ ", " ^ operand_text op2))
  | Mul { cond; s; rd; rm; rs; acc } ->
      let name = (match acc with Some _ -> "mla" | None -> "mul") ^ (if s then "s" else "") ^ cond_name cond in
      m name (String.concat ", " (List.map reg_name ([ rd; rm; rs ] @ Option.to_list acc)))
  | Mull { cond; s; signed; acc; rdlo; rdhi; rm; rs } ->
      let name = (if signed then "s" else "u") ^ (if acc then "mlal" else "mull") ^ (if s then "s" else "") ^ cond_name cond in
      m name (String.concat ", " (List.map reg_name [ rdlo; rdhi; rm; rs ]))
  | Mem { cond; load = false; size = Word; rd; rn = 13; offset = Off_imm 4; up = false; index = Pre; writeback = true; _ } ->
      m ("push" ^ cond_name cond) (reglist (1 lsl rd))
  | Mem { cond; load = true; size = Word; rd; rn = 13; offset = Off_imm 4; up = true; index = Post; user = false; _ } ->
      m ("pop" ^ cond_name cond) (reglist (1 lsl rd))
  | Mem { cond; load; size; rd; rn; offset; up; index; writeback; user } ->
      let name = (if load then "ldr" else "str")
                 ^ (match size with Word -> "" | Byte -> "b" | Half -> "h" | Sbyte -> "sb" | Shalf -> "sh" | Dword -> "d")
                 ^ (if user then "t" else "")
                 ^ cond_name cond in
      let sign = if up then "" else "-" in
      let off = match offset with
        | Off_imm 0 when up -> None
        | Off_imm n -> Some (Printf.sprintf "#%s%d" sign n)
        | Off_reg (rm, s) -> Some (sign ^ reg_name rm ^ shifted_text s) in
      (* objdump names ldrd's first register only *)
      let rds = reg_name rd in
      (* objdump drops the "!" of a halfword or doubleword transfer based
       * on pc (writing back to pc is unpredictable) *)
      let extra = size <> Word && size <> Byte in
      let writeback = writeback && not (rn = 15 && extra && (match offset with Off_imm _ -> true | Off_reg _ -> false)) in
      (* and it shows a zero offset when writing back *)
      let off = match off, offset with None, Off_imm 0 when writeback -> Some "#0" | o, _ -> o in
      let addr_text = match index, off with
        | Pre, None -> Printf.sprintf "[%s]%s" (reg_name rn) (if writeback then "!" else "")
        | Pre, Some o -> Printf.sprintf "[%s, %s]%s" (reg_name rn) o (if writeback then "!" else "")
        | Post, None -> Printf.sprintf "[%s], #0" (reg_name rn)
        | Post, Some o -> Printf.sprintf "[%s], %s" (reg_name rn) o in
      m name (rds ^ ", " ^ addr_text)
  | Block { cond; load = true; rn = 13; writeback = true; mode = IA; regs; psr = false } when regs land (regs - 1) <> 0 ->
      m ("pop" ^ cond_name cond) (reglist regs)
  | Block { cond; load = false; rn = 13; writeback = true; mode = DB; regs; psr = false } when regs land (regs - 1) <> 0 ->
      m ("push" ^ cond_name cond) (reglist regs)
  | Block { cond; load; rn; writeback; mode; regs; psr } ->
      (* objdump's older names in two cases: a single register from sp!
       * (ldmfd, stmfd), and a store incrementing after with writeback
       * (stmia) *)
      let single_sp = rn = 13 && writeback && not psr && regs land (regs - 1) = 0 in
      let suffix = match mode, load with
        | IA, true when single_sp -> "fd"
        | DB, false when single_sp -> "fd"
        | IA, false when writeback || psr -> "ia"
        | IA, _ -> "" | IB, _ -> "ib" | DA, _ -> "da" | DB, _ -> "db" in
      let name = (if load then "ldm" else "stm") ^ suffix ^ cond_name cond in
      m name (reg_name rn ^ (if writeback then "!" else "") ^ ", " ^ reglist regs ^ (if psr then "^" else ""))
  | Branch { cond; link; offset } ->
      m ((if link then "bl" else "b") ^ cond_name cond) (Bits.to_hex32 (addr + 8 + offset))
  | Bx { cond; link; rm } -> m ((if link then "blx" else "bx") ^ cond_name cond) (reg_name rm)
  | Clz { cond; rd; rm } -> m ("clz" ^ cond_name cond) (reg_name rd ^ ", " ^ reg_name rm)
  | Rev { cond; kind; rd; rm } ->
      m ((match kind with Rev32 -> "rev" | Rev16 -> "rev16" | Revsh -> "revsh") ^ cond_name cond) (reg_name rd ^ ", " ^ reg_name rm)
  | Mulhalf { cond; op; x; y; rd; rn; rm; rs } ->
      let bt b = if b then "t" else "b" in
      let r = reg_name in
      (match op with
       | Smla -> m ("smla" ^ bt x ^ bt y ^ cond_name cond) (String.concat ", " [ r rd; r rm; r rs; r rn ])
       | Smul -> m ("smul" ^ bt x ^ bt y ^ cond_name cond) (String.concat ", " [ r rd; r rm; r rs ])
       | Smlaw -> m ("smlaw" ^ bt y ^ cond_name cond) (String.concat ", " [ r rd; r rm; r rs; r rn ])
       | Smulw -> m ("smulw" ^ bt y ^ cond_name cond) (String.concat ", " [ r rd; r rm; r rs ])
       | Smlal -> m ("smlal" ^ bt x ^ bt y ^ cond_name cond) (String.concat ", " [ r rn; r rd; r rm; r rs ]))
  | Mrs { cond; rd; spsr } -> m ("mrs" ^ cond_name cond) (reg_name rd ^ if spsr then ", SPSR" else ", CPSR")
  | Coproc { cond; load; cp; opc1; crn; crm; opc2; rd } ->
      m ((if load then "mrc" else "mcr") ^ cond_name cond)
        (Printf.sprintf "%d, %d, %s, cr%d, cr%d, {%d}" cp opc1 (if load && rd = 15 then "APSR_nzcv" else reg_name rd) crn crm opc2)
  | Coproc2 { cond; load; cp; opc1; crm; rd; rd2 } ->
      m ((if load then "mrrc" else "mcrr") ^ cond_name cond) (Printf.sprintf "%d, %d, %s, %s, cr%d" cp opc1 (reg_name rd) (reg_name rd2) crm)
  | Extend { cond; signed; half; rd; rn; rm; rot } ->
      let name = (if signed then "s" else "u") ^ "xt" ^ (if rn = 15 then "" else "a") ^ (if half then "h" else "b") in
      let args = [ reg_name rd ] @ (if rn = 15 then [] else [ reg_name rn ]) @ [ reg_name rm ] in
      m (name ^ cond_name cond) (String.concat ", " args ^ if rot = 0 then "" else Printf.sprintf ", ror #%d" (8 * rot))
  | Hint { cond; hint } -> (match hint with 0 -> m ("nop" ^ cond_name cond) "{0}" | h -> [| ""; "yield"; "wfe"; "wfi"; "sev" |].(h) ^ cond_name cond)
  | Swp { cond; byte; rd; rm; rn } -> m ((if byte then "swpb" else "swp") ^ cond_name cond) (Printf.sprintf "%s, %s, [%s]" (reg_name rd) (reg_name rm) (reg_name rn))
  | Ldrex { cond; rd; rn } -> m ("ldrex" ^ cond_name cond) (Printf.sprintf "%s, [%s]" (reg_name rd) (reg_name rn))
  | Strex { cond; rd; rm; rn } -> m ("strex" ^ cond_name cond) (Printf.sprintf "%s, %s, [%s]" (reg_name rd) (reg_name rm) (reg_name rn))
  | Clrex -> "clrex"
  | Barrier { kind } -> m [| "dsb"; "dmb"; "isb" |].(kind - 4) "sy"
  | Cps { imod; a; i; f; mode } ->
      let masks = (if a then "a" else "") ^ (if i then "i" else "") ^ (if f then "f" else "") in
      let mode = match mode with Some md -> Printf.sprintf "#%d" md | None -> "" in
      (match imod with
       | 0 -> "cps\t" ^ mode
       | _ -> (if imod = 2 then "cpsie\t" else "cpsid\t") ^ masks ^ (if mode = "" then "" else ", " ^ mode))
  | Vmrs { cond; reg; rd } ->
      m ("vmrs" ^ cond_name cond) ((if rd = 15 then "APSR_nzcv" else reg_name rd) ^ ", " ^ vfp_reg_name reg)
  | Vmsr { cond; reg; rd } -> m ("vmsr" ^ cond_name cond) (vfp_reg_name reg ^ ", " ^ reg_name rd)
  | Vldst { cond; load; double; v; rn; offset } ->
      m ((if load then "vldr" else "vstr") ^ cond_name cond)
        (Printf.sprintf "%s, [%s%s]" (vname double v) (reg_name rn) (if offset = 0 then "" else Printf.sprintf ", #%d" offset))
  | Vblock { cond; load; double; rn; before; writeback; first; count } ->
      let regs = if count = 1 then vname double first else vname double first ^ "-" ^ vname double (first + count - 1) in
      if rn = 13 && writeback && load <> before then m ((if load then "vpop" else "vpush") ^ cond_name cond) ("{" ^ regs ^ "}")
      else
        m ((if load then "vldm" else "vstm") ^ (if before then "db" else "ia") ^ cond_name cond)
          (reg_name rn ^ (if writeback then "!" else "") ^ ", {" ^ regs ^ "}")
  | Vmov_single { cond; to_core; s; rt } ->
      m ("vmov" ^ cond_name cond) (if to_core then reg_name rt ^ ", " ^ vname false s else vname false s ^ ", " ^ reg_name rt)
  | Vmov_double { cond; to_core; d; rt; rt2 } ->
      let core = reg_name rt ^ ", " ^ reg_name rt2 in
      m ("vmov" ^ cond_name cond) (if to_core then core ^ ", " ^ vname true d else vname true d ^ ", " ^ core)
  | Vop { cond; op; double; d; n; m = mm } ->
      let name = match op with
        | Vmla -> "vmla" | Vmls -> "vmls" | Vnmla -> "vnmla" | Vnmls -> "vnmls" | Vmul -> "vmul" | Vnmul -> "vnmul"
        | Vadd -> "vadd" | Vsub -> "vsub" | Vdiv -> "vdiv" in
      m (name ^ cond_name cond ^ fsize double) (String.concat ", " [ vname double d; vname double n; vname double mm ])
  | Vunop { cond; op; double; d; m = mm } ->
      let name = match op with Vmov_reg -> "vmov" | Vabs -> "vabs" | Vneg -> "vneg" | Vsqrt -> "vsqrt" in
      m (name ^ cond_name cond ^ fsize double) (vname double d ^ ", " ^ vname double mm)
  | Vcmp { cond; e; double; d; m = mm } ->
      m ((if e then "vcmpe" else "vcmp") ^ cond_name cond ^ fsize double)
        (vname double d ^ ", " ^ match mm with Some r -> vname double r | None -> "#0.0")
  | Vcvt { cond; conv; double; d; m = mm } ->
      let name, dst, src = match conv with
        | Cvt_precision -> "vcvt" ^ cond_name cond ^ fsize (not double) ^ fsize double, vname (not double) d, vname double mm
        | Cvt_of_int { signed } -> "vcvt" ^ cond_name cond ^ fsize double ^ (if signed then ".s32" else ".u32"), vname double d, vname false mm
        | Cvt_to_int { signed; round_zero } ->
            (if round_zero then "vcvt" else "vcvtr") ^ cond_name cond ^ (if signed then ".s32" else ".u32") ^ fsize double,
            vname false d, vname double mm in
      m name (dst ^ ", " ^ src)
  | Msr { cond; spsr; fields; src } ->
      let names = String.concat "" (List.filter_map (fun (b, c) -> if fields land b <> 0 then Some c else None)
                                      [ 8, "f"; 4, "s"; 2, "x"; 1, "c" ]) in
      m ("msr" ^ cond_name cond) ((if spsr then "SPSR_" else "CPSR_") ^ names ^ ", " ^ operand_text src)
  | Svc { cond; imm } -> m ("svc" ^ cond_name cond) (Printf.sprintf "0x%08x" imm)
  | Undefined w -> Printf.sprintf ".word\t0x%08x" (Bits.unsigned32 w)
