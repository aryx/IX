(* tiny-ml's stack machine and its code generator. A function's code is
 * a list of instructions on a stack of values, and this module turns it
 * into tiny-machine's assembly: the values of the stack live in
 * registers r1 to r11, and the frames live on the value stack, whose
 * top is in r12. This module also makes the static blocks in the data
 * section: strings, closures, exceptions. Everything is made as
 * TinyLibMachine.mli's lines, then printed. Read
 * TinyMachine/TinyMachineCPU.mli for the instructions, and
 * runtime/ml/ml.c for the blocks. *)

type rel = Eq | Ne | Lt | Le | Gt | Ge
type op =
  | Add | Sub | Mul | Div | Mod | And | Or | Xor | Lsl | Lsr | Asr
  | Cmp of rel
  | Neg | Lnot | Not
  | IsInt                             (* an integer, not a block *)
  | Tag                               (* a block's tag *)

(* A label in the assembly: a function's code, a static block, a
 * string. *)
type sym = string

(* A function's n-ary code, or a field of the closure. *)
type target = Direct of sym | Indirect of int

type label = int                      (* a place in a function's code *)
(* Slot 0 of a frame is the closure, then the parameters and variables. *)
type slot = int

(* A binary operation's first operand is on top: arguments are pushed
 * from the last, as OCaml evaluates them. *)
type ir =
  | Imm of int64                      (* a word, an integer already tagged *)
  | Addr of sym                       (* a static block's is its value *)
  | Get of slot
  | Set of slot
  | GetG of sym * int                 (* a unit's table, an index in it *)
  | SetG of sym * int
  | Field of int                      (* replaces the block by its field *)
  | SetField of int                   (* stores the value below the block *)
  | Alloc of int * int                (* tag, n: a block of n values, the
                                       * top becoming field 0 *)
  | Blank of int * int                (* tag, n: n fields, each () *)
  | Op of op
  | Call of target * int * bool       (* the closure and n arguments; true
                                       * for a tail call *)
  | CallC of sym * int                (* a runtime function of n arguments *)
  | Label of label
  | Jmp of label
  | Jz of label                       (* false is 1, the tagged 0 *)
  | Jnz of label
  | Drop
  | Ret
  | Raise                             (* raises the top *)
  | TryEnter of int * label           (* the k-th handler, its code *)
  | TryExit of int
  | Catch of int                      (* the handler's entry; the exception
                                       * pushed *)

val label : unit -> label

(* The parameters come first after the closure in the nslots slots. *)
val machine : sym -> int -> int -> ir list -> TinyLibMachine.line list

(* The program's ml_start, called from C, and ml_raise. *)
val start : TinyLibMachine.line list

(* A unit's assembly, or the program's, as it is made, each list with
 * the last line first. *)
type asm = {
  mutable text : TinyLibMachine.line list;
  mutable data : TinyLibMachine.line list;
}
(* The new current assembly, which add_text, add_data and the static
 * blocks below add to. *)
val start_asm : unit -> asm
val add_text : TinyLibMachine.line list -> unit
val add_data : TinyLibMachine.line list -> unit
(* The code, then .data; written as an object, or as text with -S. *)
val lines : asm -> TinyLibMachine.line list

(* DCode is the label of code, DVal of a block. *)
type dword = DNum of TinyLibMachine.word | DCode of sym | DVal of sym

val words : sym -> dword list -> unit
(* [block g header ws]: g is the static block's value. *)
val block : sym -> TinyLibMachine.word -> dword list -> unit
val header : int -> int -> TinyLibMachine.word   (* n fields, tag *)
val closure_tag : int
val static_string : string -> sym     (* made once per string *)

(* The arities whose curry functions the unit needs. *)
val arities : int list ref
(* [curry n k]: for arity n, after k arguments. *)
val curry : int -> int -> sym
(* [entry n f]: what a closure of f, of n parameters, runs when called
 * with one argument. *)
val entry : int -> sym -> sym
val closure_sym : sym -> sym
val static_closure : sym -> int -> sym
(* [exn_id unit c], where unit declares c; exn_const for a constant c. *)
val exn_id : string -> string -> sym
val exn_const : string -> string -> sym
val tagged : int -> int64
