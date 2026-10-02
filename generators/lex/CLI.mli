(* mini-lex: the lexer generator. Reads a .mll, ocamllex's, and writes
 * its lexer in OCaml. Its usage: [help] in CLI.ml, what mini-lex -h
 * prints. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
