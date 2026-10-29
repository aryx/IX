(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A C function in SSA form, as types (plan_cc_ssa.md): blocks of
 * instructions, each instruction a value named by its number, a
 * block's phis choosing a value by the predecessor it is entered from.
 * Ssa_build makes it from simple's stack code after Opti's forms,
 * Alloc gives its values registers, Ssa_gen writes its assembly.
 *
 * mini-ml's ssa/ is the model, its Ssa.mli the long story; what C
 * changes is in the instructions. A value has a type (Ir.ty: its
 * size, its sign, a float), as the stack's slots had. Memory is C's:
 * a load or a store through an address, kept in the order of the
 * text, each block's body run as written. The variables SSA names are
 * the ones Opti's regs could hold (Opti.variables: an auto or a
 * parameter whose address is never taken, loaded and stored whole);
 * every other variable stays in memory, read and written by its
 * instructions as the stack code did. mini-cc -simple -O -dssa, arm:
 *
 *     long *copyw(long *q, long *p, long n)
 *     { long *e = p + n; while(p < e) *q++ = *p++; return q; }
 *
 *     b0:                              b2:      ; from b1
 *       v0 = param n+8(FP)               v10 = load v5
 *       v1 = param p+4(FP)               v9 = ADD v5 $4
 *       v2 = param q+0(FP)               v11 = store v7 v10
 *       v3 = ASHL v0 $2                  v8 = ADD v7 $4
 *       v4 = ADD v3 v1                   jmp b1
 *       jmp b1                         b3:      ; from b1
 *     b1:      ; from b0 b2              ret v7
 *       v5 = phi [b0 v1] [b2 v9]
 *       v7 = phi [b0 v2] [b2 v8]
 *       br LO v5 v4 b2 b3
 *
 * where the stack code kept q, p and e in the frame and read them at
 * each use; and the loop's code, Ssa_gen's (-S), is scan_arm.s's by
 * hand:
 *
 *     CMP     R1,R2
 *     BHS     4(PC)
 *     MOVW.P  4(R2),R4
 *     MOVW.P  R4,4(R3)
 *     B       -4(PC) *)

type value = int

type ty = Ir.ty
type mem = Ir.mem

(* an instruction; a value is its number *)
type ins =
  | Const of int64 * ty
  | Fconst of float * ty
  | Addr of mem                       (* a global's, an auto's, a
                                         parameter's address *)
  | Undef of ty                       (* a variable read before any write: 0 *)
  | Param of mem * ty                 (* a parameter's value at the entry *)
  | Phi of (int * value) list         (* a predecessor's value *)
  | Load of ty * value * int          (* through the address, at an offset *)
  | LoadAt of mem * ty                (* a variable left in memory, a global *)
  | Store of ty * value * int * value (* the address and offset, the value *)
  | StoreAt of mem * ty * value
  | Copy of int * value * value       (* n bytes: the destination, the source *)
  | Op of Tree.binop * ty * value * value     (* a o b; a relation 1 or 0 *)
  | OpImm of Tree.binop * ty * value * int64
  | Neg of ty * value
  | Com of ty * value
  | Cvt of ty * ty * value            (* from a type to another *)
  | Arg of int * ty * value           (* stored at the outgoing offset *)
  | ArgBlock of int * int * value     (* the block copied there, n bytes *)
  | Call of Ir.target * value option * ty option * ty option
                                      (* the name, or the address; the
                                         first argument's type if in R0;
                                         the result's *)

(* a comparison's second operand: a value, or an immediate *)
type operand = V of value | Imm of int64

type term =
  | Jmp of int
  | Br of Tree.binop * ty * value * operand * int * int
                                      (* to the first block if a o b,
                                         else the second *)
  | Ret of value option

type block = {
  id : int;
  mutable phis : value list;
  mutable body : value list;
  mutable term : term;
  mutable preds : int list;
}

(* types: each value's (a store's, a call's without result: a word) *)
type func = {
  name : Tree.sym;
  locals : int;
  args : int;
  r0 : (mem * ty) option;
  blocks : block array;
  defs : (value, ins) Hashtbl.t;
  types : (value, ty) Hashtbl.t;
}
