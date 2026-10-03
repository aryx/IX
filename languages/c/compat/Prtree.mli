(* mini-cc -x (sub.c's prtree): a function's tree after the checks, one
 * node a line, indented; a dump to compare two builds of mini-cc by,
 * and to debug with. Kept apart: the compiler is the same without it. *)

(* [prtree title body] *)
val prtree : string -> Tree.stmt -> string
