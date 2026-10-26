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
type target = Direct of string | Code of int
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
val machine : string -> int -> int -> ir list -> unit
type dword = DNum of string | DCode of string | DVal of string

val words : string -> dword list -> unit
val block : string -> string -> dword list -> unit
val header : int -> int -> string
val closure_tag : int
val static_string : string -> string
val arities : int list ref
val curry : int -> int -> string
val entry : int -> string -> string
val closure_sym : string -> string
val static_closure : string -> int -> string
val exn_id : string -> string
val exn_const : string -> string
val tagged : int -> int64
