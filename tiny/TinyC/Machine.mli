(* tiny-cc's code generator: turns a function's stack machine code into
 * TinyCPU's assembly, keeping the values of the stack in registers r1
 * to r12. It also makes the data of globals. Read Lower.mli first, and
 * TinyLibMachine.mli for the lines. *)

(* [machine f locals code]: the locals take [locals] bytes. *)
val machine :
  Types.sym -> int -> Lower.ir list -> TinyLibMachine.line list

(* [global g n ds]: n bytes at label g, each datum at its offset. *)
val global :
  Types.sym -> int -> (int * Tree.datum) list ->
  TinyLibMachine.line list
