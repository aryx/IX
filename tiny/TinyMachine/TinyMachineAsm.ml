(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyMachineAsm.mli *)
module ISA = TinyMachineISA

type sym = string

type line =
  | Instr of ISA.instr
  | Li of ISA.reg * int64
  | La of ISA.reg * sym
  | Mov of ISA.reg * ISA.reg
  | Call of sym
  | Jump of sym
  | Branch of ISA.cmp * ISA.reg * ISA.reg * sym
  | Ret
  | Label of sym
  | Align of int
  | Space of int
  | Bytes of int list
  | Word of int64
  | Word_sym of sym
  | Piece
  | SectionCode
  | SectionData

let reg (r : ISA.reg) =
  if r = 0 then "zero"
  else if r = ISA.sp then "sp"
  else if r = ISA.lr then "lr"
  else "r" ^ string_of_int r

(* (old: Printf's %ld of Int64.to_int32, in each compiler) *)
let word v = Int64.to_string (Int64.shift_right (Int64.shift_left v 32) 32)

(* an instruction's text: TinyMachineISA's print, but the registers by
 * their names and the offsets in words of a branch or a jal as they
 * are (no address to give them) *)
let instr (i : ISA.instr) =
  let r = reg and n = string_of_int in
  let mem off a = n off ^ "(" ^ r a ^ ")" in
  match i with
  | ISA.Alu (op, d, a, b) ->
      ISA.alu_names.(ISA.index ISA.alus op) ^ "\t" ^ r d ^ ", " ^ r a ^ ", "
      ^ r b
  | ISA.Alui (op, d, a, imm) ->
      ISA.imm_name op ^ "\t" ^ r d ^ ", " ^ r a ^ ", " ^ n imm
  | ISA.Lui (d, imm) -> "lui\t" ^ r d ^ ", " ^ ISA.hex imm
  | ISA.Load (s, d, a, off) ->
      (if s = ISA.W then "ldw" else "ldb") ^ "\t" ^ r d ^ ", " ^ mem off a
  | ISA.Store (s, d, a, off) ->
      (if s = ISA.W then "stw" else "stb") ^ "\t" ^ r d ^ ", " ^ mem off a
  | ISA.Branch (c, d, a, off) ->
      ISA.cmp_names.(ISA.index ISA.cmps c) ^ "\t" ^ r d ^ ", " ^ r a ^ ", "
      ^ n off
  | ISA.Jal (d, off) -> "jal\t" ^ r d ^ ", " ^ n off
  | ISA.Jalr (d, a, off) -> "jalr\t" ^ r d ^ ", " ^ mem off a
  | ISA.Sys k -> "sys\t" ^ n k

let print (l : line) =
  let ins s = "\t" ^ s ^ "\n" in
  match l with
  | Instr i -> ins (instr i)
  | Li (d, v) -> ins ("li\t" ^ reg d ^ ", " ^ word v)
  | La (d, s) -> ins ("la\t" ^ reg d ^ ", " ^ s)
  | Mov (d, a) -> ins ("mov\t" ^ reg d ^ ", " ^ reg a)
  | Call s -> ins ("call\t" ^ s)
  | Jump s -> ins ("j\t" ^ s)
  | Branch (c, d, a, s) ->
      ins (ISA.cmp_names.(ISA.index ISA.cmps c) ^ "\t" ^ reg d ^ ", " ^ reg a
           ^ ", " ^ s)
  | Ret -> ins "ret"
  | Label s -> s ^ ":\n"
  | Align k -> ins (".align\t" ^ string_of_int k)
  | Space k -> ins (".space\t" ^ string_of_int k)
  | Bytes l -> ins (".byte\t" ^ String.concat ", " (List.map string_of_int l))
  | Word v -> ins (".word\t" ^ word v)
  | Word_sym s -> ins (".word\t" ^ s)
  | Piece -> ins ".piece"
  | SectionCode -> ins ".text"
  | SectionData -> ins ".data"
