(* tiny-ml's stack machine and its code generator: a function's code,
 * instructions on a stack of values, as tiny-machine's assembly (the
 * stack's values in registers r1 to r11, the frames on the value stack
 * at r12); and the static blocks, in the data: strings, closures,
 * exceptions; each made as TinyLibMachine.mli's lines, then
 * printed. Read TinyMachine/TinyMachineCPU.mli for the instructions,
 * and TinyMLRuntime/core.c for the blocks. *)

type rel = Eq | Ne | Lt | Le | Gt | Ge
type op =
  | Add | Sub | Mul | Div | Mod | And | Or | Xor | Lsl | Lsr | Asr
  | Cmp of rel
  | Neg | Lnot | Not
  | IsInt                             (* an integer, not a block *)
  | Tag                               (* a block's tag *)

(* an assembly's label: a function's code, a static block, a string *)
type sym = string

(* a function's n-ary code, or a closure's field *)
type target = Direct of sym | Indirect of int

(* a place in a function's code, a number *)
type label = int
(* a slot of the function's frame on the value stack: 0 its closure,
 * then its parameters and its variables *)
type slot = int

(* a binary operation's first operand is on top: arguments are pushed
 * from the last, as OCaml evaluates them *)
type ir =
  | Imm of int64                      (* a word, an integer already tagged *)
  | Addr of sym                       (* a symbol's address: a static block's
                                       * is its value *)
  | Get of slot
  | Set of slot
  | GetG of sym * int                 (* a global of a unit: its table, its
                                       * index *)
  | SetG of sym * int
  | Field of int                      (* a block by its field *)
  | SetField of int                   (* the value below the block stored in
                                       * its field *)
  | Alloc of int * int                (* a tag, n values by the block of them,
                                       * the top its field 0 *)
  | Blank of int * int                (* a tag, a block of n fields, each () *)
  | Op of op
  | Call of target * int * bool       (* the closure then n arguments by the
                                       * result; a tail call *)
  | CallC of sym * int                (* a runtime's function of n arguments *)
  | Label of label
  | Jmp of label
  | Jz of label                       (* false is 1, the tagged 0 *)
  | Jnz of label
  | Drop
  | Ret
  | Raise                             (* the top raised *)
  | TryEnter of int * label           (* the k-th handler of the function, its
                                       * code *)
  | TryExit of int
  | Catch of int                      (* the handler's entry: the exception
                                       * pushed *)

val label : unit -> label

(* [machine f nparams nslots code]: f's assembly; its frame nslots
 * slots, its parameters the first after its closure *)
val machine : sym -> int -> int -> ir list -> TinyLibMachine.line list

(* the program's ml_start, called by C, and ml_raise *)
val start : TinyLibMachine.line list

(* A unit's assembly, or the whole program's, as it is made: its
 * functions' code (text), its static blocks (data), the last line
 * first *)
type asm = {
  mutable text : TinyLibMachine.line list;
  mutable data : TinyLibMachine.line list;
}
(* a new assembly, from then on the current one: what add_text, and the
 * static blocks below, add to *)
val start_asm : unit -> asm
val add_text : TinyLibMachine.line list -> unit
val add_data : TinyLibMachine.line list -> unit
(* its lines: the code, then the data (.data); TinyML.ml writes them
 * as an object, or as their text (-S) *)
val lines : asm -> TinyLibMachine.line list

(* a static word: a number's text, a code's label, a block's *)
type dword = DNum of int64 | DCode of sym | DVal of sym

(* [words g ws]: g's words in the data *)
val words : sym -> dword list -> unit
(* [block g header ws]: a static block, g its value *)
val block : sym -> int64 -> dword list -> unit
(* [header n tag]: a block's header *)
val header : int -> int -> int64
val closure_tag : int
(* a string's static block, made once *)
val static_string : string -> sym

(* the arities whose curry functions the unit needs *)
val arities : int list ref
(* [curry n k]: the curry function of arity n, after k arguments *)
val curry : int -> int -> sym
(* [entry n f]: the code a closure of f, of n parameters, calls with one
 * argument *)
val entry : int -> sym -> sym
val closure_sym : sym -> sym
(* [static_closure f n]: f's closure, a static block *)
val static_closure : sym -> int -> sym
(* an exception's identity, and the value of a constant one *)
val exn_id : string -> sym
val exn_const : string -> sym
(* an integer as the machine holds it, tagged *)
val tagged : int -> int64
