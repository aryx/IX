(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The program being linked, as types: its symbols, its instructions
 * (the assembler's, with what linking adds to each) and its data.
 * Link fills it, the machines (Arm, Arm64) lay its code out and encode
 * it.
 *
 * The whole program is one list of instructions, every object's one
 * after the other, each remembering its file and line for the
 * messages; a branch holds its target as the instruction itself
 * (target), not as a number, so the passes may insert, drop and
 * reorder instructions (a prologue, a literal pool, Follow) without
 * any branch to fix. Only the last pass before the encoding gives
 * each its pc.
 *
 * ['m] is the machine's opcodes. The few opcodes the general part
 * must tell apart to bind names and follow the flow (a TEXT, a
 * branch, a call) are constructors here; all the others are the
 * machine's own type, wrapped in Ins, which Link carries without
 * looking. So Link and Follow are written once, for an ['m] they
 * never inspect, and the type checker says so. *)

type kind = Undefined | Text | Data | Bss

(* a symbol: a name and a version (0, or its object's for a name<>) *)
type sym = {
  name : string;
  version : int;
  mutable kind : kind;
  mutable value : int;        (* Text: its address; Data and Bss: its offset in the data *)
  mutable size : int;         (* Data and Bss *)
  created : int;              (* the order of creation, for the data's layout *)
  mutable weak : bool;        (* named, not asked for: see Link.weak *)
}

(* Asm's conditions, here for the machines (which open Program) *)
type cond = Asm.cond = EQ | NE | HS | LO | MI | PL | VS | VC | HI | LS | GE | LT | GT | LE

(* an opcode: those this part looks at, the rest the machine's ['m] *)
(* old: a string, compared here ("B", "BEQ", "TEXT") and matched in the
 * machines with catch-alls; each machine inverted a condition with its
 * own table of strings, and a typo in one was an error at run time *)
type 'm op =
  | Func                (* TEXT *)
  | Nop
  | B
  | Bl
  | Bcond of cond       (* BEQ ... *)
  | Bcase
  | Ins of 'm

(* an instruction of the program, with what linking adds to it
 * (5l's Prog, xix's Types.node) *)
type 'm prog = {
  mutable op : 'm op;
  mutable suffixes : string list;
  mutable args : Asm.operand list;
  mutable pc : int;
  mutable target : 'm prog option;   (* a branch's target; a load's pool word (5l's p->cond) *)
  version : int;                  (* its object's, for the object's name<>s *)
  where : string * int;           (* its file and line *)
  mutable frame : int;            (* TEXT: the frame size, as written; the machine rounds it *)
  mutable leaf : bool;            (* TEXT: calls nothing *)
}

(* a DATA: a symbol, an offset, a width, a value *)
type data = { dsym : sym; off : int; width : int; value : Asm.operand; dversion : int }

type 'm t = {
  arch : Asm.arch;
  syms : (string * int, sym) Hashtbl.t;
  mutable ncreated : int;
  mutable progs : 'm prog list;
  mutable datas : data list;
  mutable text_start : int;       (* INITTEXT *)
  mutable data_start : int;       (* INITDAT *)
  mutable text_size : int;
  mutable data_size : int;
  mutable bss_size : int;
  mutable data_round : int;       (* INITRND: the data's start is rounded to it *)
  mutable pie : bool;             (* position independent (Mach-O): no absolute address in the code *)
}
