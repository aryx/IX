(* The tokens, for Parser (lex.c's yylex), by ocamllex (dune) or
 * mini-lex (the mkfile): Lexer.mll.
 *
 * C's lexer is not alone on its input: the preprocessor is in the same
 * pass (Pre: a '#' line is handled when the lexer meets it, a macro's
 * use pushes its expansion on the input stack and reads its own
 * arguments), a string's and a comment's characters are read one by
 * one (their escapes, the lines to count), and a name is a typedef's
 * or not by the symbol table (the parser needs LTYPE: C's grammar is
 * not context-free without it). So the lexbuf reads Pre's stack a
 * character at a time, and whatever the automaton read ahead is put
 * back on the stack (sync) before anything else touches the input.
 *
 * It was written by hand first, as 5c's (220 lines, for 206 here: the
 * rules replace the scanning of numbers and operators, and sync is
 * what they cost). The two give the same listings on every C file of
 * ix, for both machines.
 *
 * References: M. E. Lesk and E. Schmidt, "Lex - A Lexical Analyzer
 * Generator" (Bell Labs CSTR 39, 1975): the road 5c did not take. *)

val init : unit -> unit

(* the lexbuf, over Pre's input stack *)
val lexbuf : unit -> Lexing.lexbuf

val token : Lexing.lexbuf -> Parser.token
