(* tiny-cc's code generator: the stack machine's code of a function as
 * TinyCPU's assembly, the stack's values in registers r1 to r12; and a
 * global's data. Read TinyCLower.mli first, and
 * TinyLibMachine.mli for the lines. *)

(* [machine f locals code]: f's assembly, its locals taking that many
 * bytes of its frame *)
val machine :
  TinyCTypes.sym -> int -> TinyCLower.ir list -> TinyLibMachine.line list

(* [global g n ds]: a global of n bytes, its label and its data at their
 * offsets *)
val global :
  TinyCTypes.sym -> int -> (int * TinyCTree.datum) list ->
  TinyLibMachine.line list
