(* tiny-cc's stack machine: a function's tree of statements is lowered
 * to a list of instructions on a stack of values, with jumps to
 * numbered labels (-ir prints them). Read Tree.mli first. *)

type label = int                      (* a place in a function's code *)

type ir =
  | Imm of int64
  | Place of Tree.place          (* a variable's address *)
  | Load of Types.ty             (* replaces the address on top by its
                                  * value *)
  | Store of Types.ty            (* replaces a value and an address by
                                  * the value *)
  | Op of Tree.binop * Types.ty
      (* replaces a b by a op b, in the operands' type; a relation gives
       * 1 or 0 *)
  | Unop of Tree.unop * Types.ty
  | Ext of Types.ty              (* extends the value on top to a type *)
  | Dup
  | Drop
  | Call of Types.sym option * int * bool
      (* None when the function's address is on top of the arguments;
       * the number of arguments; whether there is a result *)
  | Label of label
  | Jmp of label
  | Jz of label
  | Jnz of label
  | Ret of bool                       (* true with a value *)

val show : ir -> string               (* as -ir prints it *)

val lower_function : Tree.stmt -> ir list
