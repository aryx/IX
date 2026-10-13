(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The database machine's bytecode (SQLite's word for its VDBE's
 * programs), as types: the instructions SQL is compiled to and the
 * values of the registers; Dbm runs it (its interface tells the
 * machine, and shows a program). *)

(* a register's, a cursor's number *)
type reg = R of int [@@unboxed]
type cursor = C of int [@@unboxed]

(* old: chidb's register, a type tag and a union; its REG_UNSPECIFIED
 * is a register never written *)
type value =
  | Unspecified
  | Null
  | Int of int              (* a 32-bit signed integer *)
  | Text of string
  | Record of string        (* a packed record, as MakeRecord makes it *)

type cmp = Eq | Ne | Lt | Le | Gt | Ge
type order = Lt | Le | Gt | Ge

(* an instruction; ['j] is where a jump goes: a label while compiling,
 * an address once resolved *)
(* old: chidb's chidb_dbm_op_t, an opcode and int32 p1, p2, p3 and a
 * char *p4, whose meaning each opcode's handler knew; a register was a
 * jump target or a cursor as the handler read it *)
type 'j instr =
  | Noop
  | Open_read of cursor * reg * int            (* the root page's register; the number of columns *)
  | Open_write of cursor * reg * int
  | Close of cursor
  | Rewind of cursor * 'j                       (* jumps if empty *)
  | Next of cursor * 'j                         (* jumps if moved *)
  | Prev of cursor * 'j
  | Seek of Cursor.seek * cursor * 'j * reg     (* jumps if none qualifies *)
  | Column of cursor * int * reg
  | Key of cursor * reg
  | Integer of int * reg
  | String of int * reg * string                (* its length, as chidb writes it *)
  | Null of reg
  | Result_row of reg * int
  | Make_record of reg * int * reg
  | Insert of cursor * reg * reg                (* the record's register, the key's *)
  | Cmp of cmp * reg * 'j * reg
  | Idx_cmp of order * cursor * 'j * reg        (* jumps if the index entry's value compares so *)
  | Idx_pkey of cursor * reg
  | Idx_insert of cursor * reg * reg            (* the value's register, the primary key's *)
  | Create of Btree.tree * reg                  (* CreateTable, CreateIndex *)
  | Copy of reg * reg
  | Scopy of reg * reg
  | Halt

(* an instruction as EXPLAIN prints it and .dbmf files write it *)
type row = { opcode : string; p1 : int; p2 : int; p3 : int; p4 : string option }
