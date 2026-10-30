(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* acid's tree (principia's acid.h: Node, and the Store of a constant,
 * one recursive structure: a value may be code, and code holds
 * constants). The values' meaning is Value's; the grammar is
 * Parser.mly, acid's dbg.y. *)

type kind =
  | Int of int64
  | Float of float
  | String of string
  | List of cell option        (* None: the empty list *)
  | Code of expr               (* what eval runs *)

(* a value and its format (Value.mli says what the letters are), and
 * its complex type, an aggr's name, when it is the address of one
 * (acid's Node's comt: what e.m reads by, what print calls) *)
and value = { kind : kind; fmt : char; comt : string option }

(* acid's lists: cells, changed in place by append and + *)
and cell = { mutable value : value; mutable next : cell option }

and binop =
  | Mul | Div | Mod | Add | Sub | Rsh | Lsh
  | Lt | Gt | Leq | Geq | Eq | Neq
  | Land | Xor | Lor

and expr =
  | Const of value
  | Name of string
  | Bin of binop * expr * expr
  | Cand of expr * expr                 (* && *)
  | Cor of expr * expr                  (* || *)
  | Assign of expr * expr
  | Fmt of expr * char                  (* e\X *)
  | Plus of expr                        (* unary + *)
  | Not of expr
  | Indm of expr                        (* *e: the process's memory *)
  | Indc of expr                        (* @e: the program's file *)
  | Preinc of expr | Predec of expr
  | Postinc of expr | Postdec of expr
  | Head of expr | Tail of expr
  | Append of expr * expr
  | Delete of expr * expr
  | Eval of expr
  | Cast of string * expr               (* (T)e: a complex type *)
  | Index of expr * expr
  | Dot of expr * string                (* e.m, e->m *)
  | Call of string * expr list * bool   (* builtin f(...): true *)
  | Construct of expr list              (* {a, b} *)
  | What of string option               (* whatis *)
  | Frame of string * string            (* f:v, a local's address *)

(* a complex type's member (aggr's): its format, its offset, its name,
 * the complex type it is, if one *)
type member = { mfmt : char; moffset : int; mname : string; mtype : string option }

type stmt =
  | Expr of expr option
  | Block of stmt list
  | If of expr * stmt * stmt option
  | Loop of expr * expr * stmt          (* loop a, b do s *)
  | While of expr * stmt
  | Return of expr
  | Local of string list
  | Complex of string * expr            (* complex T v (or f:v): v is a T *)

(* a function's parameter: its name, and whether it is *name, which
 * gets its argument's code, not its value (eval runs it) *)
type param = { pname : string; by_name : bool }

type toplevel =
  | Stmt of stmt
  | Defn of string * param list * stmt list
  | Undefn of string                    (* defn f, alone: f forgotten *)
  | Aggr of string * member list
