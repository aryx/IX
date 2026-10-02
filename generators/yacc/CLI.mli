(* mini-yacc: the parser generator. Reads a .mly, ocamlyacc's, and
 * writes its parser in OCaml and its interface. Its usage: [help] in
 * CLI.ml, what mini-yacc -h prints. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
