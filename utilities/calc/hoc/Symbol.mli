(* The names hoc knows: symbol.c's table, with init.c's constants and
 * built-ins and math.c's checks. (The keywords, which the C keeps in
 * the same table, are the lexer's.) *)

(* hoc's execerror: an error in a line, at its reading or when it runs;
 * the message, as it is printed after the program's name *)
exception Error of string

(* the name's symbol, made Undef the first time it is seen *)
val find : string -> Ast.symbol

(* a new symbol for the name, before any other of that name (the C's
 * list, a new entry at its front: the trees made so far keep the old one) *)
val install : string -> Ast.value -> Ast.symbol

(* d, the result of the function of that name: an Error for a NaN or an
 * infinity *)
val check : string -> float -> float

(* a definition is being read: return is allowed (hoc.y's indef) *)
val in_definition : bool ref
