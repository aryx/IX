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
 * Why the lexer must know the declarations:
 *
 *     T * x;         if T is a typedef's name: x declared, a pointer
 *                    if T is a variable: T times x, computed for nothing
 *     (T) - 1        a cast of -1 to T, or T minus 1
 *
 * The same tokens, two trees, and a parser that looks one token
 * ahead cannot wait to see. So a name's token is LTYPE when its
 * symbol's class is a typedef's at that moment, LNAME otherwise, and
 * the moment matters: the parser's action that declares T must have
 * run before the lexer is asked for the next T, which holds because
 * yacc runs an action as soon as its rule is reduced.
 *
 * terminology:
 * This is known as the lexer hack: the feedback from the parser's
 * symbol table to the lexer that every C compiler has in one form
 * or another. typedef lets the programmer add words to the
 * language, and the grammar has depended on the declarations since.
 *
 * road-not-taken:
 * 5c's lexer is by hand, though lex was Bell Labs' own tool for
 * exactly this (Lesk and Schmidt, 1975): a C lexer reads through
 * the preprocessor's stack, which lex's one buffer of input does not
 * fit, and by hand it is 220 lines. Here the generator is used
 * anyway, to see the price, which is sync.
 *
 * others:
 * Languages designed since made sure a file parses without knowing
 * what its names are: Go's grammar was made to be parsed with no
 * symbol table at hand. C++ went the other way, and gcc
 * (whose C parser was a yacc grammar until GCC 4.1, in 2006) and
 * clang parse both languages by hand, by recursive descent, asking
 * at each name what it is.
 *
 * References: M. E. Lesk and E. Schmidt, "Lex - A Lexical Analyzer
 * Generator" (Bell Labs CSTR 39, 1975): the road 5c did not take;
 * plan_cc.md, decision 6. *)

val init : unit -> unit

(* the lexbuf, over Pre's input stack *)
val lexbuf : unit -> Lexing.lexbuf

val token : Lexing.lexbuf -> Parser.token
