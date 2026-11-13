(* The interpreter does what run.c does, on the trees.
 *
 * A value is its cell (Ast). An expression gives the variable's own
 * cell, a field's cell, or a new one, and reading it as a number or as
 * a string may change which of the two it has. A condition is true
 * when its cell is not 0, if it has a number, and not empty
 * otherwise. *)

type caps = Io.caps

(* awk's exit; the status that the program asked for is in [status] *)
exception Exit_program

(* "" at first; after exit, its string, or "error" for a number other
 * than 0 *)
val status : string ref

(* the offset in the program's text of the statement being run *)
val position : int ref

(* run BEGIN, the rules on each record of the input, and END, then
 * close every stream *)
val run : < caps; .. > -> Ast.program -> unit
