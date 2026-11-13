(* The tokens for Parser (lex.c's yylex). Lexer.mll is compiled by
 * ocamllex under dune, or by mini-lex under the mkfile.
 *
 * C's lexer is not alone on its input:
 * - the preprocessor runs in the same pass (see Pre). A '#' line is
 *   handled when the lexer meets it, and the use of a macro pushes its
 *   expansion on the input stack and reads its own arguments;
 * - the characters of a string or a comment are read one by one, for
 *   their escapes and to count the lines;
 * - whether a name is a typedef's name is decided by the symbol table.
 *   The parser needs LTYPE because C's grammar is not context-free
 *   without it.
 * So the lexbuf reads Pre's stack a character at a time, and whatever
 * the automaton read ahead is put back on the stack (sync) before
 * anything else touches the input.
 *
 * It was first written by hand, as 5c's lexer is (220 lines, against
 * 206 here: the rules replace the code that scans numbers and
 * operators, and sync is what they cost). The two versions give the
 * same listings on every C file of ix, for both machines.
 *
 * Why the lexer must know the declarations:
 *
 *     T * x;         if T is a typedef's name, x is declared, a pointer
 *                    if T is a variable, T times x is computed for nothing
 *     (T) - 1        a cast of -1 to T, or T minus 1
 *
 * The same tokens give two different trees, and a parser that looks
 * only one token ahead cannot wait to see which. So the token for a
 * name is LTYPE when its symbol's class is typedef at that moment, and
 * LNAME otherwise. The moment matters: the parser's action that
 * declares T must have run before the lexer is asked for the next T.
 * This holds because yacc runs an action as soon as its rule is
 * reduced.
 *
 * terminology:
 * This is known as the lexer hack: the parser's symbol table feeds
 * back into the lexer, as it does in every C compiler in one form or
 * another. typedef lets the programmer add words to the language, and
 * since then the grammar has depended on the declarations.
 *
 * road-not-taken:
 * 5c's lexer is written by hand, though lex was Bell Labs' own tool
 * for exactly this job (Lesk and Schmidt, 1975). A C lexer reads
 * through the preprocessor's stack, which does not fit lex's single
 * input buffer, and written by hand it is only 220 lines. Here the
 * generator is used anyway, to see the price, which is sync.
 *
 * others:
 * Languages designed since then made sure that a file can be parsed
 * without knowing what its names are; Go's grammar was designed to be
 * parsed with no symbol table at hand. C++ went the other way. gcc
 * (whose C parser was a yacc grammar until GCC 4.1, in 2006) and clang
 * parse both languages by hand, by recursive descent, asking at each
 * name what it is.
 *
 * References: M. E. Lesk and E. Schmidt, "Lex - A Lexical Analyzer
 * Generator" (Bell Labs CSTR 39, 1975), the road 5c did not take;
 * plan_cc.md, decision 6. *)

val init : unit -> unit

(* the lexbuf, which reads Pre's input stack *)
val lexbuf : unit -> Lexing.lexbuf

val token : Lexing.lexbuf -> Parser.token
