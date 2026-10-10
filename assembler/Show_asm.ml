(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Show_asm.mli *)
open Asm

let show_name (n : name) = if n.static then n.sym ^ "<>" else n.sym

let show_shift (s : shift) =
  Printf.sprintf "R%d%s%s" s.reg (match s.kind with Lsl -> "<<" | Lsr -> ">>" | Asr -> "->" | Ror -> "@>")
    (match s.by with By_imm n -> string_of_int n | By_reg r -> Printf.sprintf "R%d" r)

let show_mem (m : mem) =
  let off = if m.off = 0L then "" else if m.off > 0L && m.name <> None then "+" ^ Int64.to_string m.off else Int64.to_string m.off in
  let base = match m.base with R r -> Printf.sprintf "(R%d)" r | SB -> "(SB)" | FP -> "(FP)" | SP -> "(SP)" | PC -> "(PC)" in
  let prefix = match m.index with Some s -> show_shift s | None -> "" in
  match m.name with
  | Some n -> Printf.sprintf "%s%s%s" (show_name n) (if off = "" then "+0" else off) base
  | None -> Printf.sprintf "%s%s%s" prefix (if off = "" then "0" else off) base

(* a place on a formatter: what a derived printer calls for a mem
 * (mini-cc's -dir) *)
let pp_mem fmt m = Format.pp_print_string fmt (show_mem m)

let show_operand = function
  | Reg r -> Printf.sprintf "R%d" r
  | FReg f -> Printf.sprintf "F%d" f
  | Special s -> s
  | Spr v -> Printf.sprintf "SPR(0x%Lx)" v
  | Imm n -> "$" ^ Int64.to_string n
  | Fimm x -> Printf.sprintf "$%h" x
  | Str s -> Printf.sprintf "$%S" s
  | Mem m -> show_mem m
  | Addr m -> "$" ^ show_mem m
  | Shifted s -> show_shift s
  | Regs rs -> "[" ^ String.concat "," (List.map (Printf.sprintf "R%d") rs) ^ "]"
  | Pair (a, b) -> Printf.sprintf "(R%d, R%d)" a b
  | Target i -> Printf.sprintf "#%d" i

let show_item = function
  | Text (n, flag, frame) -> Printf.sprintf "TEXT %s(SB), %d, $%Ld" (show_name n) flag frame
  | Globl (n, flag, size) -> Printf.sprintf "GLOBL %s(SB), %d, $%Ld" (show_name n) flag size
  | Data (n, off, w, v) -> Printf.sprintf "DATA %s+%Ld(SB)/%d, %s" (show_name n) off w (show_operand v)
  | Ins i ->
      String.concat "." (i.op :: i.suffixes) ^ (if i.args = [] then "" else " ")
      ^ String.concat ", " (List.map show_operand i.args)
