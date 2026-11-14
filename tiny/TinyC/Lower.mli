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
  (* A local or a parameter of 1 or 4 bytes whose address is never taken
   * is read and written by these two, so that Machine can keep it in a
   * register. *)
  | Get of Tree.place * Types.ty     (* pushes the variable's value *)
  | Set of Tree.place * Types.ty     (* stores the value on top in the
                                      * variable, and keeps it *)

val show : ir -> string               (* as -ir prints it *)

(* A function's code, and the variables its Get and Set read and write,
 * the heaviest first, with their type and their weight (their uses, 8
 * times more in each loop around them). *)
val lower_function :
  Tree.stmt -> ir list * (Tree.place * (Types.ty * int)) list
