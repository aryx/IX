(* tiny-cc's code generator: turns a function's stack machine code into
 * TinyCPU's assembly, keeping the values of the stack in registers r1
 * up, and the function's heaviest variables in the registers above the
 * deepest its stack goes, up to r12. It also makes the data of globals.
 * Read Lower.mli first, and TinyLibMachine.mli for the lines. *)

(* [machine f locals (code, vars)]: the locals take [locals] bytes; vars
 * are the variables of code's Get and Set, as Lower.lower_function gives
 * them. *)
val machine :
  Types.sym -> int ->
  Lower.ir list * (Tree.place * (Types.ty * int)) list ->
  TinyLibMachine.line list

(* [global g n ds]: n bytes at label g, each datum at its offset. *)
val global :
  Types.sym -> int -> (int * Tree.datum) list ->
  TinyLibMachine.line list
