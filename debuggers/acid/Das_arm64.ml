(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Das_arm64.mli *)

let bits w lo n = Int64.to_int (Int64.logand (Int64.shift_right_logical w lo) (Int64.pred (Int64.shift_left 1L n)))

(* a field of n bits, its sign extended *)
let sbits w lo n = let v = bits w lo n in if v land (1 lsl (n - 1)) <> 0 then v - (1 lsl n) else v

let conds = [| "EQ"; "NE"; "HS"; "LO"; "MI"; "PL"; "VS"; "VC"; "HI"; "LS"; "GE"; "LT"; "GT"; "LE"; "AL"; "NV" |]

(* a condition, by the flags NZCV (the PSR's top four bits) *)
let holds cond psr =
  let f k = Int64.logand (Int64.shift_right_logical psr k) 1L = 1L in
  let n = f 31 and z = f 30 and c = f 29 and v = f 28 in
  let r = match cond lsr 1 with
    | 0 -> z | 1 -> c | 2 -> n | 3 -> v | 4 -> c && not z | 5 -> n = v | 6 -> n = v && not z | _ -> true in
  if cond land 1 = 1 && cond <> 15 then not r else r

type kind =
  | Branch of int64                       (* B, BL: always *)
  | Cond of int64 * ((string -> int64) -> bool)   (* taken when, by the registers *)
  | Indirect of int * bool                (* BR, BLR, RET: a register; a call *)
  | Other

let kind w pc =
  let off n = Int64.add pc (Int64.of_int (n * 4)) in
  if Int64.logand w 0x7c000000L = 0x14000000L then Branch (off (sbits w 0 26))
  else if Int64.logand w 0xff000010L = 0x54000000L then
    let c = bits w 0 4 in
    Cond (off (sbits w 5 19), fun reg -> holds c (reg "PSR"))
  else if Int64.logand w 0x7e000000L = 0x34000000L then
    let r = bits w 0 5 and nz = bits w 24 1 = 1 and wide = bits w 31 1 = 1 in
    Cond (off (sbits w 5 19), fun reg ->
      let v = reg (Printf.sprintf "R%d" r) in
      let v = if wide then v else Int64.logand v 0xffffffffL in
      (v <> 0L) = nz)
  else if Int64.logand w 0x7e000000L = 0x36000000L then
    let r = bits w 0 5 and nz = bits w 24 1 = 1 and b = (bits w 31 1 lsl 5) lor bits w 19 5 in
    Cond (off (sbits w 5 14), fun reg ->
      (Int64.logand (Int64.shift_right_logical (reg (Printf.sprintf "R%d" r)) b) 1L = 1L) = nz)
  else if Int64.logand w 0xff9ffc1fL = 0xd61f0000L then
    Indirect (bits w 5 5, bits w 21 2 = 1)
  else Other

let follow get reg pc =
  match get pc with
  | None -> None
  | Some w ->
      match kind w pc with
      | Branch t -> Some t
      | Cond (t, taken) -> Some (if taken reg then t else Int64.add pc 4L)
      | Indirect (r, _) -> Some (reg (Printf.sprintf "R%d" r))
      | Other -> Some (Int64.add pc 4L)

let reg n = if n = 31 then "ZR" else Printf.sprintf "R%d" n
let sp n = if n = 31 then "RSP" else Printf.sprintf "R%d" n

let instruction symoff get pc =
  match get pc with
  | None -> "?"
  | Some w ->
      let target t = symoff t in
      match kind w pc with
      | Branch t -> Printf.sprintf "%s\t%s" (if bits w 31 1 = 1 then "BL" else "B") (target t)
      | Cond (t, _) when Int64.logand w 0xff000010L = 0x54000000L -> Printf.sprintf "B%s\t%s" conds.(bits w 0 4) (target t)
      | Cond (t, _) when Int64.logand w 0x7e000000L = 0x34000000L ->
          Printf.sprintf "%s\t%s, %s" (if bits w 24 1 = 1 then "CBNZ" else "CBZ") (reg (bits w 0 5)) (target t)
      | Cond (t, _) ->
          Printf.sprintf "%s\t$%d, %s, %s" (if bits w 24 1 = 1 then "TBNZ" else "TBZ")
            ((bits w 31 1 lsl 5) lor bits w 19 5) (reg (bits w 0 5)) (target t)
      | Indirect (30, false) when bits w 21 2 = 2 -> "RET"
      | Indirect (r, call) -> Printf.sprintf "%s\t(%s)" (if call then "BL" else (if bits w 21 2 = 2 then "RET" else "B")) (reg r)
      | Other ->
          if w = 0xd503201fL then "NOP"
          else if Int64.logand w 0xffe0001fL = 0xd4200000L then Printf.sprintf "BRK\t$%d" (bits w 5 16)
          (* ADD, SUB of a constant (64 bits): MOV to and from SP too *)
          else if Int64.logand w 0x7f800000L = 0x11000000L || Int64.logand w 0x7f800000L = 0x51000000L then begin
            let imm = bits w 10 12 lsl (if bits w 22 1 = 1 then 12 else 0) in
            let op = if bits w 30 1 = 1 then "SUB" else "ADD" in
            if imm = 0 && op = "ADD" then Printf.sprintf "MOV\t%s, %s" (sp (bits w 5 5)) (sp (bits w 0 5))
            else Printf.sprintf "%s\t$%d, %s, %s" op imm (sp (bits w 5 5)) (sp (bits w 0 5))
          end
          (* STP, LDP of two 64-bit registers: pre-index, offset, post-index *)
          else if Int64.logand w 0xfe000000L = 0xa8000000L then begin
            let mode = bits w 23 2 and load = bits w 22 1 = 1 in
            let off = sbits w 15 7 * 8 in
            let pair = Printf.sprintf "(%s, %s)" (reg (bits w 0 5)) (reg (bits w 10 5)) in
            let addr = Printf.sprintf "%d(%s)" off (sp (bits w 5 5)) in
            let suffix = match mode with 3 -> ".W" | 1 -> ".P" | _ -> "" in
            if load then Printf.sprintf "LDP%s\t%s, %s" suffix addr pair else Printf.sprintf "STP%s\t%s, %s" suffix pair addr
          end
          (* MOV Rm, Rd (ORR Rd, ZR, Rm, 64 bits) *)
          else if Int64.logand w 0xffe0ffe0L = 0xaa0003e0L then Printf.sprintf "MOV\t%s, %s" (reg (bits w 16 5)) (reg (bits w 0 5))
          (* LDR, STR of 64 and 32 bits, an unsigned offset *)
          else if Int64.logand w 0xbfc00000L = 0xb9400000L || Int64.logand w 0xbfc00000L = 0xb9000000L then begin
            let wide = bits w 30 1 = 1 and load = bits w 22 1 = 1 in
            let off = bits w 10 12 * (if wide then 8 else 4) in
            let op = if wide then "MOV" else "MOVW" in
            let addr = Printf.sprintf "%d(%s)" off (sp (bits w 5 5)) in
            if load then Printf.sprintf "%s\t%s, %s" op addr (reg (bits w 0 5)) else Printf.sprintf "%s\t%s, %s" op (reg (bits w 0 5)) addr
          end
          (* MOVZ: a constant *)
          else if Int64.logand w 0x7f800000L = 0x52800000L then
            Printf.sprintf "MOV\t$%d, %s" (bits w 5 16 lsl (16 * bits w 21 2)) (reg (bits w 0 5))
          else Printf.sprintf "WORD\t$0x%08Lx" w
