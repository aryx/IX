(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The tree once its names are resolved and its types checked
 * (Tiger_semant): each variable is its declaration, each call its
 * function, each expression has its type; the type declarations are
 * gone, a record type is one record whatever it was named. It is what
 * the back end (Tiger_emit) reads, and what a second back end, to C--
 * or to the machine (plan_cmm.md), would read too.
 *
 * The functions are given their nesting: each knows the function it
 * was declared in (its static parent), and each variable whether a
 * function nested in its own uses it (it "escapes", Appel's chapter 6),
 * which is what decides where it lives on .NET: a local of IL, or a
 * field of its function's frame, an object. *)

type ty =
  | Int
  | String
  | Unit
  | Nil                       (* nil's own: it goes where a record goes *)
  | Record of record
  | Array of array_

(* each record or array type declared is new: two of the same shape
 * are two types (Tiger's equality of types is by name) *)
and record = { rname : string; rid : int; mutable rfields : (string * ty) list }
and array_ = { aname : string; aid : int; mutable elem : ty }

type var = {
  vname : string;
  vid : int;
  mutable vty : ty;           (* nil's, for a var x := nil, until x is given a record *)
  vfun : func;                (* the function that declares it *)
  param : int;                (* its place among the parameters, -1 if a local *)
  mutable escapes : bool;     (* a function nested in vfun uses it *)
  readonly : bool;            (* a for's variable *)
}

and func = {
  name : string;              (* unique: the method's *)
  fid : int;
  parent : func option;       (* the static parent; None for the program *)
  mutable params : var list;
  mutable result : ty;
  mutable nested : bool;      (* has functions of its own: then a frame *)
  mutable vars : var list;    (* its parameters and locals, as declared *)
  mutable fbody : exp option;
}

and exn = { ename : string; eid : int }

and exp = { e : desc; ty : ty }

and desc =
  | Nil_e
  | Int_e of int32
  | String_e of string
  | Var_e of lvalue
  | Op_e of exp * Tiger_ast.oper * exp
  | Call_e of func * exp list
  | Builtin_e of string * exp list
  | Record_e of record * exp list         (* the fields in their order *)
  | Array_e of array_ * exp * exp
  | Seq_e of exp list
  | Assign_e of lvalue * exp
  | If_e of exp * exp * exp option
  | While_e of exp * exp
  | For_e of var * exp * exp * exp
  | Break_e
  | Let_e of (var * exp) list * exp       (* the variables declared, with their values in order *)
  | Try_e of exp * (exn * exp) list
  | Raise_e of exn

and lvalue =
  | Simple of var
  | Field of lvalue * record * int        (* its place among the fields *)
  | Subscript of lvalue * array_ * exp

(* a program: its main function (the program's expression its body),
 * all the functions, records and exceptions declared *)
type program = {
  main : func;
  funcs : func list;
  records : record list;
  exns : exn list;
}
