(* The interpreter: run.c, on the trees.
 *
 * A value is its cell (Ast): an expression gives the variable's own
 * cell, a field's, or a new one, and reading it as a number or as a
 * string may change which of the two it has. A condition is true when
 * its cell is not 0 if it has a number, not empty otherwise. *)

type caps = Io.caps

(* awk's exit: the status the program asked for is in [status] *)
exception Exit_program

(* "" at first; exit's: its string, or "error" for a number not 0 *)
val status : string ref

(* the offset in the program's text of the statement being run *)
val position : int ref

(* BEGIN, the rules on each record of the input, END, then every
 * stream closed *)
val run : < caps; .. > -> Ast.program -> unit
