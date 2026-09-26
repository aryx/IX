(* The ssa back end's IR (plan: variants/ssa.md), phase 1: a function
 * of Lower's stack machine in SSA form, printed by mini-ml -dssa and
 * checked, not yet compiled.
 *
 * The blocks are the stack code's runs between labels and jumps (a
 * try's handler a successor of the block its try ends), those the
 * entry does not reach dropped, as Gen drops dead code. The
 * construction is Braun, Buchwald, Hack, Leissa, Mallon and Zwinkau's
 * ("Simple and Efficient Construction of Static Single Assignment
 * Form", CC 2013): a frame's slot, and a position of the stack at a
 * block's edge, are variables; a stack entry inside a block is a
 * value; a block is sealed when its predecessors are all filled, and
 * the phis it needed then get their operands; the trivial ones (one
 * value, and themselves) go at the end. No dominance frontiers.
 *
 * A function with a handler keeps its slots in memory (slot, setslot):
 * its handler would need each slot's value at whichever point raised,
 * which is for later. The check: every use dominated by its
 * definition (Cooper, Harvey and Kennedy's dominators), a phi's
 * operands its block's predecessors. *)

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
  | Op of Lower.op * value list       (* a o b is [a; b], as the stack's top first *)
  | Call of Lower.target * value list (* the closure, then the arguments *)
  | CallC of string * value list
  | Caught of int                     (* at a handler's entry, the exception *)
  | TryExit of int

type term =
  | Jmp of int
  | Br of value * int * int           (* to the first block if true, else the second *)
  | Try of int * int * int            (* the k-th handler: the body, the handler *)
  | Ret of value
  | Raise of value
  | Tail of Lower.target * value list

type block = {
  id : int;
  mutable phis : value list;
  mutable body : value list;
  mutable term : term;
  mutable preds : int list;
}

type func = { name : string; nparams : int; blocks : block array; defs : (value, ins) Hashtbl.t }

(* built, the trivial phis out, checked (Failure if not) *)
val func : Lower.func -> func

(* -dssa *)
val show : func -> string

(* mini-ml -ssa, phase 2: each function through SSA and back to the
 * stack machine, every value in its own slot, for simple's Gen *)
val unit_ : Lower.unit_ -> Lower.unit_
