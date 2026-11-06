type rel = Eq | Ne | Lt | Le | Gt | Ge
type op =
    Add
  | Sub
  | Mul
  | Div
  | Mod
  | And
  | Or
  | Xor
  | Lsl
  | Lsr
  | Asr
  | Cmp of rel
  | Neg
  | Lnot
  | Not
  | IsInt
  | Tag
(* an assembly's label: a function's code, a static block, a string *)
type sym = string
type target = Direct of sym | Indirect of int
type ir =
    Imm of int64
  | Addr of string * int
  | Get of int
  | Set of int
  | GetG of string * int
  | SetG of string * int
  | Field of int
  | SetField of int
  | Alloc of int * int
  | Blank of int * int
  | Op of op
  | Call of target * int * bool
  | CallC of string * int
  | Label of int
  | Jmp of int
  | Jz of int
  | Jnz of int
  | Drop
  | Ret
  | Raise
  | TryEnter of int * int
  | TryExit of int
  | Catch of int
val label : unit -> int
val text : Buffer.t
val data : Buffer.t
val machine : sym -> int -> int -> ir list -> unit
(* a static word: a number's text, a code's label, a block's *)
type dword = DNum of string | DCode of sym | DVal of sym

val words : sym -> dword list -> unit
val block : sym -> string -> dword list -> unit
val header : int -> int -> string
val closure_tag : int
val static_string : string -> sym
val arities : int list ref
val curry : int -> int -> sym
val entry : int -> sym -> sym
val closure_sym : sym -> sym
val static_closure : sym -> int -> sym
val exn_id : string -> sym
val exn_const : string -> sym
val tagged : int -> int64
