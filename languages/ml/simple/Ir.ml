(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The stack machine Lower compiles to, as types: an expression pushes
 * its value, an operation pops its operands, statements are labels and
 * jumps. Nothing here knows the machine: an integer is an ML integer
 * (Gen tags it), a static block a symbol (Gen adds a word for its
 * value), and a frame's slots are numbers. Arguments are pushed from
 * the last, as OCaml evaluates them, so an operation's first operand
 * is on top. Opti rewrites this code, Ssa reads it, Gen and Emit write
 * its assembly.
 *
 * A function's code, as mini-ml -dir prints it (slot 0 is the
 * closure, 1 and 2 the parameters, the others the function's own):
 *
 *     let rec loop i acc = if i = 0 then acc else loop (i - 1) (acc + i)
 *
 *     Int 0; Get 1; Op (Cmp Eq); Jz 3      i = 0? (i pushed last: on top)
 *     Get 2; Ret                           acc
 *     Label 3
 *     Get 1; Get 2; Op Add; Set 3          acc + i, the last argument first
 *     Int 1; Get 1; Op Sub; Set 4          i - 1
 *     Block "cf3_loop<>"; Set 5            loop's closure, a static block
 *     Call (Direct "f3_loop<>", [5; 4; 3], true)   a tail call
 *
 * Two things to see. A call's operands are not on the stack but in
 * slots, named by the call: at a call nothing is left in a register
 * (Gen.mli says why, the collector). And = is [Cmp Eq], the
 * integers', because the type checker saw an int (Lower.immediates);
 * at a type it did not know, or with -unsafe-types, it is [Poly Eq],
 * which tests at run time whether both are integers and calls compare
 * for the others (Opti's eqs sees a constant, and makes it [Cmp Eq]).
 *
 * design:
 * A stack machine needs no decision from the compiler that makes its
 * code: no register to choose, no temporary to name, one construct
 * of the tree is one sequence of instructions whatever is around it.
 * The decisions are put off to Gen, which makes few (depth i of the
 * stack is register i). The same form is mini-cc's simple back
 * end's (its Ir), TinyC's and tiny-ml's; Ssa is what one moves to
 * when one wants to decide better.
 *
 * cs-history:
 * A stack machine between a compiler's two halves is as old as
 * Pascal's P-code (Zurich, the 1970s), which carried the language to
 * dozens of machines: the compiler made P-code, and a new machine
 * needed only its interpreter. Caml Light's ZINC and OCaml's
 * bytecode, Java's (1995) and WebAssembly (2017) are stack machines
 * for the same reason, compact and easy to make code for. Here the
 * code is not interpreted and never leaves the compiler. *)

(* -dir's printers (show, show_op) are derived (dune: ppx_deriving;
 * mini-ml: mlpp), ppx_deriving's text: (Ir.Call ((Ir.Direct "f"), [1],
 * false)); these are what a compiler without deriving is left with, as
 * xix does *)
let show_op _ = "NO DERIVING"
[@@warning "-32"]
let show _ = "NO DERIVING"
[@@warning "-32"]

type rel = Eq | Ne | Lt | Le | Gt | Ge [@@deriving show]

type op =
  | Add | Sub | Mul | Div | Mod | And | Or | Xor | Lsl | Lsr | Asr
  | Cmp of rel          (* integers *)
  | Poly of rel         (* compare's: inlined on integers, else the runtime's *)
  | Neg | Not | IsInt | Tag | Size
[@@deriving show]

type target = Direct of string | Code of int
[@@deriving show]

type t =
  | Int of int                        (* an ML integer, tagged by Gen *)
  | Block of string                   (* a static block's value: its symbol + a word *)
  | Sym of string                     (* a symbol's address: a function's code *)
  | Get of int | Set of int           (* a slot of the function's frame on the value stack *)
  | GetG of string | SetG of string   (* a global *)
  | Field of int                      (* a block by its field *)
  | SetField of int * bool            (* the value below the block stored in its field *)
  | Index                             (* a block, an index (ML) by the field; bounds checked *)
  | SetIndex of bool                  (* a block, an index, a value; bounds checked *)
  (* (the stores' bool: the value an immediate, an int, a char...: no
   * write barrier, the runtime's generations; Lower.immediates) *)
  (* a string's byte read and written in place, and its length
   * (Lower.strings_in_place; calls of the runtime otherwise); true: the
   * index checked, the safe accessors' *)
  | ByteGet of bool                   (* a string, an index by the byte there *)
  | ByteSet of bool                   (* a string, an index, a byte *)
  | StrLen                            (* a string by its length *)
  (* two floats by a new one, their sum, difference, product or
   * quotient; an integer by its float; a float by its integer: the
   * processor's instructions (Lower.floats_in_place), by the name of
   * the runtime's function that does the same (caml_addfloat...: called
   * otherwise, and when there is no room for the new float) *)
  | Float2 of string                  (* x, y by x op y *)
  | Float1 of string                  (* x by -x, or by its absolute value *)
  | FloatOfInt
  | IntOfFloat
  | FloatCmp of rel                   (* x, y by x rel y, two floats (Lower.floats) *)
  (* a float of a Float.Array, its doubles in the block (the runtime's
   * Double_array_tag); true: the index checked. A call of the runtime
   * (ml_floatarray_get...) but in ssa's code on doubles (Unbox), where
   * it is a load and a store of the processor's *)
  | FloatIndex of bool                (* a float array, an index by the float there *)
  | FloatSetIndex of bool             (* a float array, an index, a float *)
  | Alloc of int * int                (* a tag, n values by the block, the top its field 0 *)
  | Op of op
  | Call of target * int list * bool  (* the slots of the closure then of the arguments; a tail call *)
  | CallC of string * int             (* the runtime's function of n arguments *)
  | Label of int | Jmp of int
  | Jz of int | Jnz of int            (* false is the ML 0 *)
  | Drop
  | Ret
  | Raise                             (* the top raised; its place taken by the result, never seen *)
  | TryEnter of int * int             (* the k-th handler of the function, its code *)
  | TryExit of int
  | Catch of int                      (* the handler's entry: the exception pushed *)
[@@deriving show]

type func = { name : string; nparams : int; nslots : int; code : t list }

(* the static data *)
type data =
  | String of string * string         (* a string block: symbol, bytes *)
  | Float of string * string          (* a float's block: symbol, the literal *)
  | Boxed_int of string * int * string    (* an int32's or int64's block: symbol, 32 or 64, the literal *)
  | Closure of string * string * string   (* symbol: [entry code; n-ary code] *)
  | Exception of string * string      (* an exception: symbol, its name's string symbol *)
  | Global of string * string option  (* a global, statically a block's value *)
  | Roots of string * string list     (* the unit's globals, for the collector *)

type unit_ = { funcs : func list; data : data list }
