(* A lexer written in OCaml, on Lexing's engine (lib_core's): the
 * header, the tables, a function for each rule, the trailer.
 *
 *     let rec token lexbuf =
 *       match Lexing.engine __tables 0 lexbuf with
 *       | 0 -> let n = Lexing.lexeme lexbuf in
 *     # 12 "Lexer.mll"
 *                            ( INT (int_of_string n) )
 *       ...
 *     and comment depth lexbuf = match Lexing.engine __tables 57 lexbuf with ...
 *
 * An action is copied at its column after a line # n "file.mll", so
 * that a compiler's error in it names the .mll's line.
 *
 * r as x: the whole clause's is the lexeme (or its character), with no
 * work. Another is found by matching the clause's regexp again on the
 * lexeme alone (Lexing.captures, with the regexp written here as a
 * value): x is a string, a char when it names one character each time,
 * an option of them when a way through the regexp doesn't bind it.
 *
 * Another language's lexer (C's) would be another module as this one,
 * on the same automaton. *)

(* the .mll's name and the lexer's, for the # lines; the lexer's text *)
val ocaml : file:string -> out:string -> Lex.t -> Dfa.t -> string
