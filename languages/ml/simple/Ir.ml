(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The stack machine Lower compiles to, as types: an expression pushes
 * its value, an operation pops its operands, statements are labels and
 * jumps. Nothing here knows the machine: an integer is an ML integer
 * (Gen tags it), a static block a symbol (Gen adds a word for its
 * value), and a frame's slots are numbers. Arguments are pushed from
 * the last, as OCaml evaluates them, so an operation's first operand
 * is on top. Opti rewrites this code, Ssa reads it, Gen and Emit write
 * its assembly. *)

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
  | SetField of int                   (* the value below the block stored in its field *)
  | Index                             (* a block, an index (ML) by the field; bounds checked *)
  | SetIndex                          (* a block, an index, a value; bounds checked *)
  (* a string's byte read and written in place, and its length: the
   * unchecked accessors' (Lower.strings_in_place; calls of the runtime
   * otherwise, as the checked ones are) *)
  | ByteGet                           (* a string, an index by the byte there *)
  | ByteSet                           (* a string, an index, a byte *)
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
