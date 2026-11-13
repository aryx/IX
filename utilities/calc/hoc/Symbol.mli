(* The names hoc knows: symbol.c's table, with init.c's constants and
 * built-ins and math.c's checks. (The keywords, which the C keeps in
 * the same table, are the lexer's.) *)

(* hoc's execerror: an error in a line, found when the line is read or
 * when it runs. The string is the message, as it is printed after the
 * program's name. *)
exception Error of string

(* the name's symbol, made Undef the first time the name is seen *)
val find : string -> Ast.symbol

(* makes a new symbol for the name, which hides any other of that name
 * (the C puts a new entry at the front of its list, so the trees made
 * so far keep the old one) *)
val install : string -> Ast.value -> Ast.symbol

(* returns d, the result of the function of that name, or raises an
 * Error when d is a NaN or an infinity *)
val check : string -> float -> float

(* true while a definition is being read, where return is allowed
 * (hoc.y's indef) *)
val in_definition : bool ref
