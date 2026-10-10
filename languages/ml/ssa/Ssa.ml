(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A function in SSA form, as types (plan: variants/ssa.md): blocks of
 * instructions, each instruction a value named by its number, a
 * block's phis choosing a value by the predecessor it is entered from.
 * Ssa_build makes it from Ir's stack code, Alloc gives its values
 * registers, Emit writes its assembly.
 *
 * Static single assignment: each name is given its value at one place
 * of the text. A slot of the stack machine written twice is two
 * values, and where two paths meet with different values, a phi makes
 * a third. mini-ml -dir, then -dssa:
 *
 *     let pick b x y = let r = if b then x + 1 else y in r * 2
 *
 *     Get 1; Jz 3                    b0: v1 = param 1       b
 *     Int 1; Get 2; Op Add; Jmp 4        v2 = param 2       x
 *     Label 3                            v3 = param 3       y
 *     Get 3                              br v1 b1 b2
 *     Label 4                        b1: v4 = int 1
 *     Set 4                              v5 = Add v2 v4
 *     Int 2; Get 4; Op Mul; Ret          jmp b3
 *                                    b2: jmp b3
 *                                    b3: v6 = phi [b1 v5] [b2 v3]
 *                                        v7 = int 2
 *                                        v8 = Mul v6 v7
 *                                        ret v8
 *
 * The stack is gone: what was on it at an instruction is that
 * instruction's operands, by name. So is the question every analysis
 * of the stack code must ask, which write of slot 4 does this read
 * see: a value has one definition, and a use names it. Where a value
 * is live, what a register may hold, which computation is done twice
 * are then read off the names (Alloc).
 *
 * cs-history:
 * SSA is IBM's, of the 1980s: Barry Rosen, Mark Wegman and Kenneth
 * Zadeck, and Bowen Alpern with the last two, used it in 1988 to
 * find computations made twice, and with Ron Cytron and Jeanne
 * Ferrante gave in 1991 the way to build it with as few phis as
 * needed, by the dominance frontiers. Since LLVM (2003) and GCC 4
 * (2005) it is what an optimizing compiler's middle is written in,
 * Go's since 2016.
 * ocamlopt's is not SSA: it names virtual registers that are
 * assigned many times.
 *
 * reframe:
 * SSA is a functional program (Andrew Appel, 1998): a block is a
 * function, its phis are its parameters, and a jump is a tail call
 * that gives them their values: b3 above is fun v6 -> v6 * 2,
 * called with v5 from b1 and with v3 from b2. An ML compiler that
 * goes to SSA comes back to where it started, a language whose
 * variables never change; the compilers that kept the lambdas to
 * the end (continuation-passing style, Appel's own) had the
 * property all along.
 *
 * References: R. Cytron, J. Ferrante, B. Rosen, M. Wegman and K.
 * Zadeck, "Efficiently computing static single assignment form and
 * the control dependence graph" (ACM TOPLAS 13(4), 1991); Andrew
 * Appel, "SSA is functional programming" (ACM SIGPLAN Notices 33(4),
 * 1998), four pages; Ssa_build.mli for the construction used here;
 * docs/plans/variants/ssa.md. *)

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
