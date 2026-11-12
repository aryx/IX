(* tiny-cc's stack machine: a function's tree of statements lowered to
 * a list of instructions on a stack of values, the jumps to numbered
 * labels (-ir prints them). Read Tree.mli first. *)

(* a place in a function's code, a number *)
type label = int

type ir =
  | Imm of int64
  | Place of Tree.place          (* a variable's address *)
  | Load of Types.ty             (* the address on top by its value *)
  | Store of Types.ty            (* value and address by the value *)
  | Op of Tree.binop * Types.ty
      (* a b by a op b, of the operands' type; a relation 1 or 0 *)
  | Unop of Tree.unop * Types.ty
  | Ext of Types.ty              (* the value on top to a type *)
  | Dup
  | Drop
  | Call of Types.sym option * int * bool
      (* the function, or its address on top of the arguments; their
       * number; a result *)
  | Label of label
  | Jmp of label
  | Jz of label
  | Jnz of label
  | Ret of bool                       (* with a value *)

(* an instruction as -ir prints it *)
val show : ir -> string

(* a function's body, its code *)
val lower_function : Tree.stmt -> ir list
