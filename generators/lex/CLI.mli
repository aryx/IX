(* mini-lex: the lexer generator. It reads a lexer's description in
 * ocamllex's format (a .mll) and writes the lexer in OCaml. Its usage is
 * [help] in CLI.ml, which is what mini-lex -h prints.
 *
 * A lexer cuts a text into tokens, and what a token looks like is best
 * described by a regular expression; for example, a number is digit+.
 * A lexer could try each expression in turn at each place of the text.
 * A generator instead makes one automaton of all of them, which reads
 * each character only once, however many expressions there are.
 *
 *     Lexer.mll                        when the lexer is made
 *        | Lex      reads the description: regexps, actions kept as text
 *     Lex.t
 *        | Dfa      turns all the clauses of a rule into one automaton
 *     Dfa.t
 *        | Output   writes the tables as strings, and a function per rule
 *     Lexer.ml
 *     - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 *     characters                       when the lexer runs
 *        | Lexing.engine (in lib_core) goes from a state to the next by
 *        | a character; the last accepting state passed gives the token
 *     the number of a clause, whose action the function runs
 *
 * In ix, the lexer descriptions are those of the compilers (the
 * Lexer.mll of mini-ml and of mini-cc), of their highlighters, and of
 * awk, bc, hoc and the database. The dune build gives them to ocamllex.
 * The mini-mk build, where ix is built by ix, gives them to this
 * program, and gives the grammars to mini-yacc. The small lexers, such
 * as the shell's and the assembler's, are written by hand.
 *
 * cs-history:
 * Mike Lesk wrote Lex (Bell Labs, 1975) to go with yacc: the parser
 * that yacc generates asks for its next token by calling yylex, and lex
 * writes yylex. Eric Schmidt, then a student intern at Bell Labs,
 * rewrote it and is the second author of the paper. Descriptions are
 * still written today the way lex introduced: a regular expression,
 * then in braces the code to run when it matches. The longest match is
 * taken, and of two matches of the same length, the first one wins.
 *
 * evolution:
 * flex (Vern Paxson, 1987) is a free rewrite of lex with faster
 * tables, and it is what a Linux system has under the name lex.
 * ocamllex (Xavier Leroy, for Caml Light, then OCaml) adapts the same
 * idea to ML. An action is an expression whose value is the token, and
 * a rule is a function. Where lex has start conditions (a state set by
 * hand, for example for the inside of a comment or a string), ocamllex
 * has several rules that call each other. An example is the comment
 * rule in Lex.mli's example, which counts the nesting depth in its
 * parameter.
 *
 * others:
 * Many compilers have no generated lexer. Instead they have a function
 * with a switch on the token's first character; Plan 9's C compilers
 * (principia's cc/lex.c) and rc work this way. Such a lexer is longer
 * to write, but you can see where each character is read. Here the
 * lexers of mini-cc and mini-ml are descriptions, with one clause per
 * line, and the code that reads the characters is the engine, written
 * once for all of them.
 *
 * References: M. E. Lesk and E. Schmidt, "Lex -- A Lexical Analyzer
 * Generator" (Bell Laboratories Computing Science Technical Report 39,
 * 1975); the OCaml manual's chapter "Lexer and parser generators
 * (ocamllex, ocamlyacc)"; Aho, Sethi, Ullman, "Compilers" (1986),
 * chapter 3; principia's generators/lex (Unix's lex, in C); xix's
 * generators/lex (ocamllex's sources). *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
