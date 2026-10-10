(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A function in SSA form, as types (plan: variants/ssa.md): blocks of
 * instructions, each instruction a value named by its number, a
 * block's phis choosing a value by the predecessor it is entered from.
 * Ssa_build makes it from Ir's stack code, Alloc gives its values
 * registers, Emit writes its assembly. *)

type value = int

(* an instruction; a value is its number *)
type ins =
  | Const of int                      (* an ML integer *)
  | Zero                              (* a slot never written: the prologue's raw 0 *)
  | Blk of string                     (* a static block's value *)
  | Symb of string
  | Param of int                      (* 0 the closure, then the arguments *)
  | Phi of (int * value) list         (* a predecessor's value *)
  | GetG of string
  | SetG of string * value
  | Slot of int                       (* a slot in memory (a function with a handler) *)
  | SetSlot of int * value
  | Field of int * value              (* the k-th field of a block *)
  | SetField of int * value * value   (* k, the block, the value *)
  | Index of value * value            (* the block, the index *)
  | SetIndex of value * value * value
  | Alloc of int * value list         (* the tag, the fields *)
  | Op of Ir.op * value list          (* a o b is [a; b], as the stack's top first *)
  | Call of Ir.target * value list    (* the closure, then the arguments *)
  | CallC of string * value list
  | Caught of int                     (* at a handler's entry, the exception *)
  | TryExit of int

type term =
  | Jmp of int
  | Br of value * int * int           (* to the first block if true, else the second *)
  | Try of int * int * int            (* the k-th handler: the body, the handler *)
  | Ret of value
  | Raise of value
  | Tail of Ir.target * value list

type block = {
  id : int;
  mutable phis : value list;
  mutable body : value list;
  mutable term : term;
  mutable preds : int list;
}

type func = { name : string; nparams : int; blocks : block array; defs : (value, ins) Hashtbl.t }
