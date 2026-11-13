(* Writes a lexer in OCaml that runs on Lexing's engine (in lib_core).
 * The lexer has the header, the tables, a function for each rule, and
 * the trailer.
 *
 *     let rec token lexbuf =
 *       match Lexing.engine __tables 0 lexbuf with
 *       | 0 -> let n = Lexing.lexeme lexbuf in
 *     # 12 "Lexer.mll"
 *                            ( INT (int_of_string n) )
 *       ...
 *     and comment depth lexbuf = match Lexing.engine __tables 57 lexbuf with ...
 *
 * An action is copied at its column, after a line # n "file.mll", so
 * that a compiler error in it names the line in the .mll.
 *
 * For r as x, when x names the whole clause, it is the lexeme (or its
 * one character), at no cost. Any other x is found by matching the
 * clause's regexp again on the lexeme alone (Lexing.captures, with the
 * regexp written here as a value). Then x is a string, or a char when
 * it names one character each time, and an option of either when some
 * way through the regexp does not bind it.
 *
 * A lexer in another language (C) would be written by another module
 * like this one, from the same automaton. *)

(* file and out are the names of the .mll and of the lexer, for the
 * # lines; the result is the lexer's text *)
val ocaml : file:string -> out:string -> Lex.t -> Dfa.t -> string
