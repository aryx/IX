(* mini-lex: the lexer generator. Reads a .mll, ocamllex's, and writes
 * its lexer in OCaml. Its usage: [help] in CLI.ml, what mini-lex -h
 * prints.
 *
 * A lexer cuts a text into tokens, and what a token looks like is best
 * said by a regular expression: a number is digit+. Each expression
 * could be tried in turn at each place of the text; a generator makes
 * of all of them one automaton, which reads a character once however
 * many expressions there are.
 *
 *     Lexer.mll                        when the lexer is made
 *        | Lex      the description read: regexps, the actions as text
 *     Lex.t
 *        | Dfa      a rule's clauses, all of them, as one automaton
 *     Dfa.t
 *        | Output   the tables as strings, a function a rule
 *     Lexer.ml
 *     - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 *     characters                       when the lexer runs
 *        | Lexing.engine (lib_core's): from a state, by a character, to
 *        | the next; the last accepting state passed is the token
 *     a clause's number: the function runs its action
 *
 * In ix the descriptions are the compilers' (mini-ml's and mini-cc's
 * Lexer.mll), their highlighters', and those of awk, bc, hoc and the
 * database. dune's build gives them to ocamllex; mini-mk's, where ix is
 * built by ix, to this program, with mini-yacc beside it for the
 * grammars. The lexers that are a line's worth are written by hand:
 * the shell's, the assembler's.
 *
 * cs-history:
 * Lex is Mike Lesk's (Bell Labs, 1975), made to go with yacc: yacc's
 * parser asks for its next token by calling yylex, and lex writes
 * yylex. Eric Schmidt, an intern there as a student, rewrote it
 * and is the paper's second author. The description is
 * still the one written
 * today: a regular expression, then in braces the code to run when it
 * matches, the longest match taken and, of two as long, the first.
 *
 * evolution:
 * flex (Vern Paxson, 1987) is lex again, free and with faster tables:
 * what a Linux has under the name. ocamllex (Xavier Leroy, for Caml
 * Light, then OCaml) is the same idea made ML's: an action is an
 * expression and its value the token, a rule is a function, and where
 * lex has start conditions (a state set by hand, for the inside of a
 * comment or a string) there are several rules that call each other:
 * the comment rule of Lex.mli's example, which counts its depth in
 * its parameter.
 *
 * others:
 * Many compilers have no generated lexer: a function with a switch on
 * the token's first character, as Plan 9's C compilers (principia's
 * cc/lex.c) and rc. It is longer to write, and each character read is
 * there to be seen. Here mini-cc's and mini-ml's lexers are
 * descriptions, a clause a line, and what reads a character is the
 * engine, once for all of them.
 *
 * References: M. E. Lesk and E. Schmidt, "Lex -- A Lexical Analyzer
 * Generator" (Bell Laboratories Computing Science Technical Report 39,
 * 1975); the OCaml manual's chapter "Lexer and parser generators
 * (ocamllex, ocamlyacc)"; Aho, Sethi, Ullman, "Compilers" (1986),
 * chapter 3; principia's generators/lex (Unix's lex, in C); xix's
 * generators/lex (ocamllex's sources). *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
