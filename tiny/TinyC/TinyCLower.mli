type ir =
    Imm of int64
  | Place of TinyCTree.place
  | Load of TinyCTypes.ty
  | Store of TinyCTypes.ty
  | Op of TinyCTree.binop * TinyCTypes.ty
  | Unop of TinyCTree.unop * TinyCTypes.ty
  | Ext of TinyCTypes.ty
  | Dup
  | Drop
  | Call of string option * int * bool
  | Label of int
  | Jmp of int
  | Jz of int
  | Jnz of int
  | Ret of bool
val show : ir -> string
val code : ir list ref
type targets = {
  brk : int option;
  cont : int option;
  cases : (int64 option * int) list ref;
}
val lower : targets -> TinyCTree.stmt -> unit
