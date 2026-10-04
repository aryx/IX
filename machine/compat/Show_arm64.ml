(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Show_arm64.mli *)
open Arm64

let reg_name sf ~sp r =
  match sf, r with
  | X, 31 -> if sp then "sp" else "xzr"
  | W, 31 -> if sp then "wsp" else "wzr"
  | X, r -> "x" ^ string_of_int r
  | W, r -> "w" ^ string_of_int r

let x r = reg_name X ~sp:false r
let xsp r = reg_name X ~sp:true r

let cond_name = function
  | EQ -> "eq" | NE -> "ne" | CS -> "cs" | CC -> "cc" | MI -> "mi" | PL -> "pl" | VS -> "vs" | VC -> "vc"
  | HI -> "hi" | LS -> "ls" | GE -> "ge" | LT -> "lt" | GT -> "gt" | LE -> "le" | AL -> "al" | NV -> "nv"

let invert c = conds.(let rec idx i = if conds.(i) = c then i else idx (i + 1) in idx 0 lxor 1)

let shift_name = function LSL -> "lsl" | LSR -> "lsr" | ASR -> "asr" | ROR -> "ror"

let extend_name = function
  | UXTB -> "uxtb" | UXTH -> "uxth" | UXTW -> "uxtw" | UXTX -> "uxtx"
  | SXTB -> "sxtb" | SXTH -> "sxth" | SXTW -> "sxtw" | SXTX -> "sxtx"

let logic_name invert = function
  | AND -> if invert then "bic" else "and"
  | ORR -> if invert then "orn" else "orr"
  | EOR -> if invert then "eon" else "eor"
  | ANDS -> if invert then "bics" else "ands"

(* a 64-bit address: objdump prints negative targets in 64 bits *)
let target a = Printf.sprintf "0x%Lx" (Int64.of_int a)

let hex v = Printf.sprintf "#0x%x" v
let hex64 v = Printf.sprintf "#0x%Lx" v
let dec v = Printf.sprintf "#%d" v

let shifted shift amount = if amount = 0 && shift = LSL then "" else Printf.sprintf ", %s #%d" (shift_name shift) amount

(* a value MOVZ or MOVN can load: the mov alias of ORR yields to them *)
let move_wide sf v =
  let v = Int64.logand v (ones (width sf)) in
  let one_chunk v = List.length (List.filter (fun k -> Int64.logand (Int64.shift_right_logical v (16 * k)) 0xffffL <> 0L)
                                   (List.init (width sf / 16) Fun.id)) <= 1 in
  one_chunk v || one_chunk (Int64.logand (Int64.lognot v) (ones (width sf)))

let mem_operand ~addr a amount =
  match a with
  | Literal off -> target (addr + off)
  | Base { rn; offset; mode = (Offset | Unscaled | Unpriv) } ->
      if offset = 0 then Printf.sprintf "[%s]" (xsp rn) else Printf.sprintf "[%s, #%d]" (xsp rn) offset
  | Base { rn; offset; mode = Pre } -> Printf.sprintf "[%s, #%d]!" (xsp rn) offset
  | Base { rn; offset; mode = Post } -> Printf.sprintf "[%s], #%d" (xsp rn) offset
  | Index { rn; rm; extend; s } ->
      let rm_sf = if extend = UXTX || extend = SXTX then X else W in
      let ext = match extend, s with
        | UXTX, false -> ""
        | UXTX, true -> Printf.sprintf ", lsl #%d" amount
        | e, false -> ", " ^ extend_name e
        | e, true -> Printf.sprintf ", %s #%d" (extend_name e) amount in
      Printf.sprintf "[%s, %s%s]" (xsp rn) (reg_name rm_sf ~sp:false rm) ext

let pair_operand rn offset mode =
  match mode with
  | P_offset | P_nontemporal -> if offset = 0 then Printf.sprintf "[%s]" (xsp rn) else Printf.sprintf "[%s, #%d]" (xsp rn) offset
  | P_pre -> Printf.sprintf "[%s, #%d]!" (xsp rn) offset
  | P_post -> Printf.sprintf "[%s], #%d" (xsp rn) offset

(* claude: the floating point's registers, by size *)
let fs double = if double then D else S
let freg fsize r = Printf.sprintf "%s%d" (match fsize with S -> "s" | D -> "d" | Q -> "q") r

let print ~addr (i : t) =
  let m name args = if args = "" then name else name ^ "\t" ^ args in
  let args l = String.concat ", " l in
  match i with
  | Add_imm { sf; sub = false; s = false; rd; rn; imm = 0; lsl12 = false } when rd = 31 || rn = 31 ->
      m "mov" (args [ reg_name sf ~sp:true rd; reg_name sf ~sp:true rn ])
  | Add_imm { sf; sub; s; rd; rn; imm; lsl12 } ->
      let rest = hex imm ^ if lsl12 then ", lsl #12" else "" in
      if s && rd = 31 then m (if sub then "cmp" else "cmn") (args [ reg_name sf ~sp:true rn; rest ])
      else m ((if sub then "sub" else "add") ^ if s then "s" else "") (args [ reg_name sf ~sp:(not s) rd; reg_name sf ~sp:true rn; rest ])
  | Add_reg { sf; sub; s; rd; rn; rm; shift; amount } ->
      let r = reg_name sf ~sp:false in
      let rest = r rm ^ shifted shift amount in
      if s && rd = 31 then m (if sub then "cmp" else "cmn") (args [ r rn; rest ])
      else if sub && rn = 31 then m (if s then "negs" else "neg") (args [ r rd; rest ])
      else m ((if sub then "sub" else "add") ^ if s then "s" else "") (args [ r rd; r rn; rest ])
  | Add_ext { sf; sub; s; rd; rn; rm; extend; amount } ->
      let rm_sf = if sf = X && (extend = UXTX || extend = SXTX) then X else W in
      let as_lsl = (rn = 31 || ((not s) && rd = 31)) && extend = (if sf = X then UXTX else UXTW) in
      let ext =
        if as_lsl then (if amount = 0 then "" else Printf.sprintf ", lsl #%d" amount)
        else ", " ^ extend_name extend ^ if amount = 0 then "" else Printf.sprintf " #%d" amount in
      let rest = reg_name rm_sf ~sp:false rm ^ ext in
      if s && rd = 31 then m (if sub then "cmp" else "cmn") (args [ reg_name sf ~sp:true rn; rest ])
      else m ((if sub then "sub" else "add") ^ if s then "s" else "") (args [ reg_name sf ~sp:(not s) rd; reg_name sf ~sp:true rn; rest ])
  | Adc { sf; sub; s; rd; rn; rm } ->
      let r = reg_name sf ~sp:false in
      if sub && rn = 31 then m (if s then "ngcs" else "ngc") (args [ r rd; r rm ])
      else m ((if sub then "sbc" else "adc") ^ if s then "s" else "") (args [ r rd; r rn; r rm ])
  | Logic_imm { sf; op; rd; rn; imm } ->
      let value = hex64 imm in
      if op = ANDS && rd = 31 then m "tst" (args [ reg_name sf ~sp:false rn; value ])
      (* movz cannot write sp: mov then, whatever the value *)
      else if op = ORR && rn = 31 && (rd = 31 || not (move_wide sf imm)) then m "mov" (args [ reg_name sf ~sp:true rd; value ])
      else m (logic_name false op) (args [ reg_name sf ~sp:(op <> ANDS) rd; reg_name sf ~sp:false rn; value ])
  | Logic_reg { sf; op; invert; rd; rn; rm; shift; amount } ->
      let r = reg_name sf ~sp:false in
      if op = ORR && (not invert) && rn = 31 && amount = 0 && shift = LSL then m "mov" (args [ r rd; r rm ])
      else if op = ORR && invert && rn = 31 then m "mvn" (args [ r rd; r rm ^ shifted shift amount ])
      else if op = ANDS && (not invert) && rd = 31 then m "tst" (args [ r rn; r rm ^ shifted shift amount ])
      else m (logic_name invert op) (args [ r rd; r rn; r rm ^ shifted shift amount ])
  | Movz { sf; rd; imm16; hw } when not (imm16 = 0 && hw <> 0) ->
      m "mov" (args [ reg_name sf ~sp:false rd; hex64 (Int64.shift_left (Int64.of_int imm16) (16 * hw)) ])
  | Movn { sf; rd; imm16; hw } when not (imm16 = 0 && hw <> 0) && not (sf = W && imm16 = 0xffff) ->
      let v = Int64.logand (Int64.lognot (Int64.shift_left (Int64.of_int imm16) (16 * hw))) (ones (width sf)) in
      m "mov" (args [ reg_name sf ~sp:false rd; hex64 v ])
  | Movz { sf; rd; imm16; hw } | Movn { sf; rd; imm16; hw } | Movk { sf; rd; imm16; hw } ->
      let name = match i with Movz _ -> "movz" | Movn _ -> "movn" | _ -> "movk" in
      m name (args [ reg_name sf ~sp:false rd; hex imm16 ^ if hw = 0 then "" else Printf.sprintf ", lsl #%d" (16 * hw) ])
  | Sbfm { sf; rd; rn; immr; imms } | Ubfm { sf; rd; rn; immr; imms } | Bfm { sf; rd; rn; immr; imms } ->
      let r = reg_name sf ~sp:false and bits = width sf in
      let top = bits - 1 in
      let signed = (match i with Sbfm _ -> true | _ -> false) and ins = (match i with Bfm _ -> true | _ -> false) in
      let three name a b = m name (args [ r rd; r rn; dec a; dec b ]) in
      if ins then
        if imms < immr then (if rn = 31 then m "bfc" (args [ r rd; dec ((bits - immr) mod bits); dec (imms + 1) ])
                             else three "bfi" ((bits - immr) mod bits) (imms + 1))
        else three "bfxil" immr (imms - immr + 1)
      else if imms = top then m (if signed then "asr" else "lsr") (args [ r rd; r rn; dec immr ])
      else if (not signed) && imms + 1 = immr then m "lsl" (args [ r rd; r rn; dec (top - imms) ])
      else if immr = 0 && (imms = 7 || imms = 15 || (signed && imms = 31)) && (signed || sf = W) then
        m ((if signed then "sxt" else "uxt") ^ (match imms with 7 -> "b" | 15 -> "h" | _ -> "w")) (args [ r rd; reg_name W ~sp:false rn ])
      else if imms < immr then three (if signed then "sbfiz" else "ubfiz") ((bits - immr) mod bits) (imms + 1)
      else three (if signed then "sbfx" else "ubfx") immr (imms - immr + 1)
  | Extr { sf; rd; rn; rm; lsb } ->
      let r = reg_name sf ~sp:false in
      if rn = rm then m "ror" (args [ r rd; r rn; dec lsb ]) else m "extr" (args [ r rd; r rn; r rm; dec lsb ])
  | Adr { page; rd; offset } ->
      let t = if page then Int64.add (Int64.of_int (addr land lnot 0xfff)) (Int64.shift_left (Int64.of_int offset) 12)
              else Int64.of_int (addr + offset) in
      m (if page then "adrp" else "adr") (args [ x rd; Printf.sprintf "0x%Lx" t ])
  | Csel { sf; inc; inv; rd; rn; rm; cond } ->
      let r = reg_name sf ~sp:false in
      let ok = cond <> AL && cond <> NV in
      let c = cond_name (invert cond) in
      (match inc, inv with
       | true, false when ok && rn = 31 && rm = 31 -> m "cset" (args [ r rd; c ])
       | false, true when ok && rn = 31 && rm = 31 -> m "csetm" (args [ r rd; c ])
       | true, false when ok && rn = rm && rn <> 31 -> m "cinc" (args [ r rd; r rn; c ])
       | false, true when ok && rn = rm && rn <> 31 -> m "cinv" (args [ r rd; r rn; c ])
       | true, true when ok && rn = rm -> m "cneg" (args [ r rd; r rn; c ])
       | _ ->
           let name = match inc, inv with false, false -> "csel" | true, false -> "csinc" | false, true -> "csinv" | true, true -> "csneg" in
           m name (args [ r rd; r rn; r rm; cond_name cond ]))
  | Ccmp { sf; neg; rn; imm; rm; nzcv; cond } ->
      let r = reg_name sf ~sp:false in
      m (if neg then "ccmn" else "ccmp") (args [ r rn; (if imm then hex rm else r rm); hex nzcv; cond_name cond ])
  | Rbit { sf; rd; rn } -> m "rbit" (args [ reg_name sf ~sp:false rd; reg_name sf ~sp:false rn ])
  | Rev { sf; bytes; rd; rn } ->
      let name = if bytes = width sf / 8 then "rev" else "rev" ^ string_of_int (bytes * 8) in
      m name (args [ reg_name sf ~sp:false rd; reg_name sf ~sp:false rn ])
  | Clz { sf; cls; rd; rn } -> m (if cls then "cls" else "clz") (args [ reg_name sf ~sp:false rd; reg_name sf ~sp:false rn ])
  | Div { sf; signed; rd; rn; rm } ->
      let r = reg_name sf ~sp:false in m (if signed then "sdiv" else "udiv") (args [ r rd; r rn; r rm ])
  | Shiftv { sf; shift; rd; rn; rm } -> let r = reg_name sf ~sp:false in m (shift_name shift) (args [ r rd; r rn; r rm ])
  | Madd { sf; sub; rd; rn; rm; ra } ->
      let r = reg_name sf ~sp:false in
      if ra = 31 then m (if sub then "mneg" else "mul") (args [ r rd; r rn; r rm ])
      else m (if sub then "msub" else "madd") (args [ r rd; r rn; r rm; r ra ])
  | Maddl { signed; sub; rd; rn; rm; ra } ->
      let p = if signed then "s" else "u" and w = reg_name W ~sp:false in
      if ra = 31 then m (p ^ if sub then "mnegl" else "mull") (args [ x rd; w rn; w rm ])
      else m (p ^ if sub then "msubl" else "maddl") (args [ x rd; w rn; w rm; x ra ])
  | Mulh { signed; rd; rn; rm } -> m (if signed then "smulh" else "umulh") (args [ x rd; x rn; x rm ])
  | B { link; offset } -> m (if link then "bl" else "b") (target (addr + offset))
  | Bcond { cond; offset } -> m ("b." ^ cond_name cond) (target (addr + offset))
  | Cbz { sf; nz; rt; offset } -> m (if nz then "cbnz" else "cbz") (args [ reg_name sf ~sp:false rt; target (addr + offset) ])
  | Tbz { nz; rt; bit; offset } ->
      m (if nz then "tbnz" else "tbz") (args [ reg_name (if bit < 32 then W else X) ~sp:false rt; dec bit; target (addr + offset) ])
  | Br { link; rn } -> m (if link then "blr" else "br") (x rn)
  | Ret 30 -> "ret"
  | Ret rn -> m "ret" (x rn)
  | Mem { load; size; signed; rt; addr = a } ->
      let kind = match a with Base { mode = Unscaled; _ } -> "ur" | Base { mode = Unpriv; _ } -> "tr" | _ -> "r" in
      let suffix = (if signed <> None then "s" else "") ^ (match size with Byte -> "b" | Half -> "h" | Word when signed <> None -> "w" | _ -> "") in
      let name = (if load then "ld" else "st") ^ kind ^ suffix in
      let rsf = match signed, size with Some sf, _ -> sf | None, Dword -> X | None, _ -> W in
      let rt = reg_name rsf ~sp:false rt in
      m name (args [ rt; mem_operand ~addr a (size_shift size) ])
  | Pair { load; sf; signed; rt; rt2; rn; offset; mode } ->
      let name = (if load then "ld" else "st") ^ (if mode = P_nontemporal then "np" else "p") ^ if signed then "sw" else "" in
      let rsf = if signed then X else sf in
      m name (args [ reg_name rsf ~sp:false rt; reg_name rsf ~sp:false rt2; pair_operand rn offset mode ])
  | Fmem { load; fsize; rt; addr = a } ->
      let kind = match a with Base { mode = Unscaled; _ } -> "ur" | _ -> "r" in
      m ((if load then "ld" else "st") ^ kind) (args [ freg fsize rt; mem_operand ~addr a (fsize_shift fsize) ])
  | Fpair { load; fsize; rt; rt2; rn; offset; mode } ->
      let name = (if load then "ld" else "st") ^ if mode = P_nontemporal then "np" else "p" in
      m name (args [ freg fsize rt; freg fsize rt2; pair_operand rn offset mode ])
  | Fop2 { double; op; rd; rn; rm } ->
      let name = match op with Fadd -> "fadd" | Fsub -> "fsub" | Fmul -> "fmul" | Fdiv -> "fdiv" | Fnmul -> "fnmul" in
      let r = freg (fs double) in
      m name (args [ r rd; r rn; r rm ])
  | Fop1 { double; op; rd; rn } ->
      let name = match op with Fmov -> "fmov" | Fabs -> "fabs" | Fneg -> "fneg" | Fsqrt -> "fsqrt" in
      let r = freg (fs double) in
      m name (args [ r rd; r rn ])
  | Fmadd { double; neg; sub; rd; rn; rm; ra } ->
      let name = match neg, sub with false, false -> "fmadd" | false, true -> "fmsub" | true, false -> "fnmadd" | true, true -> "fnmsub" in
      let r = freg (fs double) in
      m name (args [ r rd; r rn; r rm; r ra ])
  | Fcmp { double; e; rn; rm } ->
      let r = freg (fs double) in
      m (if e then "fcmpe" else "fcmp") (args [ r rn; (match rm with Some rm -> r rm | None -> "#0.0") ])
  | Fcsel { double; rd; rn; rm; cond } ->
      let r = freg (fs double) in
      m "fcsel" (args [ r rd; r rn; r rm; cond_name cond ])
  | Fcvt { to_double; rd; rn } ->
      m "fcvt" (args [ freg (fs to_double) rd; freg (fs (not to_double)) rn ])
  | Fcvt_int { double; sf; signed; rd; rn } ->
      m (if signed then "fcvtzs" else "fcvtzu") (args [ reg_name sf ~sp:false rd; freg (fs double) rn ])
  | Cvtf { double; sf; signed; rd; rn } ->
      m (if signed then "scvtf" else "ucvtf") (args [ freg (fs double) rd; reg_name sf ~sp:false rn ])
  | Fmov_gen { double; to_fp; rd; rn } ->
      let sf = if double then X else W in
      if to_fp then m "fmov" (args [ freg (fs double) rd; reg_name sf ~sp:false rn ])
      else m "fmov" (args [ reg_name sf ~sp:false rd; freg (fs double) rn ])
  | Fmov_imm { double; rd; imm8 } ->
      m "fmov" (args [ freg (fs double) rd; Printf.sprintf "#%.18e" (Int64.float_of_bits (fp_expand_imm imm8)) ])
  | Movi { rd; esize; imm8; amount } ->
      if esize = 64 then m "movi" (args [ Printf.sprintf "d%d" rd; hex64 (movi_value ~esize ~imm8 ~amount) ])
      else
        let lanes = match esize with 8 -> "8b" | 16 -> "4h" | _ -> "2s" in
        m "movi" (args ([ Printf.sprintf "v%d.%s" rd lanes; hex imm8 ] @ if amount = 0 then [] else [ Printf.sprintf "lsl #%d" amount ]))
  | Shift_scalar { signed; rd; rn; shift } ->
      m (if signed then "sshr" else "ushr") (args [ Printf.sprintf "d%d" rd; Printf.sprintf "d%d" rn; dec shift ])
  | Svc imm -> m "svc" (hex imm)
  | Hvc imm -> m "hvc" (hex imm)
  | Smc imm -> m "smc" (hex imm)
  | Brk imm -> m "brk" (hex imm)
  | Nop -> "nop"
  | Hint h -> (match h with Yield -> "yield" | Wfe -> "wfe" | Wfi -> "wfi" | Sev -> "sev" | Sevl -> "sevl")
  | Mrs { rt; sr } -> m "mrs" (args [ x rt; sysreg_name sr ])
  | Msr { rt; sr } -> m "msr" (args [ sysreg_name sr; x rt ])
  | Msr_imm { field; imm } ->
      m "msr" (args [ (match field with Spsel -> "spsel" | Daifset -> "daifset" | Daifclr -> "daifclr"); hex imm ])
  | Sys { op; rt } ->
      let kind, name, reg = sysop op in
      m kind (if reg then args [ name; x rt ] else name)
  | Barrier { kind = (Dsb | Dmb) as k; option } ->
      let names = [| ""; "oshld"; "oshst"; "osh"; ""; "nshld"; "nshst"; "nsh"; "";
                     "ishld"; "ishst"; "ish"; ""; "ld"; "st"; "sy" |] in
      (match k, option with
       | Dsb, 0 -> "ssbb"
       | Dsb, 4 -> "pssbb"
       | _ ->
           let name = if k = Dsb then "dsb" else "dmb" in
           m name (if names.(option) = "" then hex option else names.(option)))
  | Barrier { kind = (Isb | Clrex) as k; option } ->
      let name = if k = Isb then "isb" else "clrex" in
      if option = 15 then name else m name (hex option)
  | Eret -> "eret"
  | Excl { load; size; ordered; exclusive; rs; rt; rn } ->
      let suffix = match size with Byte -> "b" | Half -> "h" | _ -> "" in
      let name = match load, exclusive, ordered with
        | true, true, _ -> (if ordered then "ldaxr" else "ldxr")
        | false, true, _ -> (if ordered then "stlxr" else "stxr")
        | true, false, true -> "ldar" | true, false, false -> "ldlar"
        | false, false, true -> "stlr" | false, false, false -> "stllr" in
      let r = reg_name (if size = Dword then X else W) ~sp:false rt and where = Printf.sprintf "[%s]" (xsp rn) in
      m (name ^ suffix) (args (if exclusive && not load then [ reg_name W ~sp:false rs; r; where ] else [ r; where ]))
  | Undefined w when w land 0xffff = w -> Printf.sprintf "udf\t#%d" w
  | Undefined w -> Printf.sprintf ".inst\t0x%08x" (Bits.unsigned32 w)
