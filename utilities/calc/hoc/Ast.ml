(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* hoc's programs as trees: what hoc.y compiles, while it parses, to the
 * code of a stack machine (code.c's prog, an array of pointers to
 * functions, its jumps patched once a statement is read), the parser
 * here gives as a statement, which Eval runs as it is. *)

(* A name and what it is now: hoc.h's Symbol, its type and its union.
 * A name is in the trees by its symbol, not its text: what it is can
 * change after the tree is made (a formal is a variable for the time of
 * a call; a name may become a function). *)
type symbol = { name : string; mutable value : value }

and value =
  | Undef   (* seen, never assigned *)
  | Var of float
  | Builtin of (float -> float)
  | Func of def
  | Proc of def

and def = { formals : symbol list; body : stmt }

and expr =
  | Number of float
  | Variable of symbol
  | Assign of symbol * assign * expr
  | Binary of expr * binary * expr
  | Negate of expr
  | Not of expr
  (* ++x, x--: what is added, and whether the value is the new one *)
  | Step of symbol * float * bool
  | Call of symbol * expr list
  | Apply of (float -> float) * expr
  (* read(x): the next number of the input into x; 0 at its end, else 1 *)
  | Read of symbol

and assign = Set | Add_to | Sub_to | Mul_to | Div_to | Mod_to

and binary = Add | Sub | Mul | Div | Mod | Power | Gt | Ge | Lt | Le | Eq | Ne | And | Or

and stmt =
  | Expr of expr
  | Return of expr option
  | Call_proc of symbol * expr list
  | Print of item list
  | While of expr * stmt
  (* for (init; condition; step) body *)
  | For of expr * expr * expr * stmt
  | If of expr * stmt * stmt option
  | Block of stmt list

and item = Value of expr | Text of string

(* What a line of the input is: a statement to run, an expression whose
 * value is printed, nothing (an empty line, a definition: done when
 * read), or the end of the input *)
type line = Run of stmt | Show of expr | Nothing | End
