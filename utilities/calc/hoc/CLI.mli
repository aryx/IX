(* mini-hoc is Plan 9's hoc, a calculator in floating point with
 * variables, with if, while and for, and with functions that may call
 * themselves:
 *
 *     func fac(n) { if (n <= 1) return 1
 *       return n * fac(n-1) }
 *     fac(10)
 *     3628800
 *     x = 3
 *     sqrt(x^2 + 16)
 *     5
 *
 * Here is the way a line goes through the modules:
 *
 *     Input --> Lexer --> Parser --> Ast --> Eval --> what is printed
 *     the files'          a line's          |
 *     characters          tree              Symbol: the names, and what
 *                                           each one is now (a variable,
 *                                           a built-in, a function)
 *
 * It is a whole language in small: a lexer, a yacc grammar, a symbol
 * table and an interpreter, some 500 lines of OCaml (the .ml files
 * and the lexer) besides the grammar. It is the one to read before the
 * shell's interpreter (mini-rc's Eval), awk's (Run) or the compilers.
 *
 * cs-history:
 * hoc is a book's program. Chapter 8, "Program Development", of
 * Kernighan and Pike's "The UNIX Programming Environment" (1984) grows
 * it in six stages to show yacc, lex and make at work:
 * - hoc1 has the four operations, computed in the grammar's actions;
 * - hoc2 adds variables;
 * - hoc3 adds names of any length and the built-in functions, with a
 *   symbol table;
 * - hoc4 computes the same things, but by compiling to the code of a
 *   stack machine;
 * - hoc5 adds if and while;
 * - hoc6 adds functions, procedures and recursion.
 * The name stands for "high-order calculator". Plan 9's hoc is hoc6
 * taken a little further: its functions' parameters have names, where
 * the book's are $1, $2.
 *
 * The command line: its usage and a few examples are [help] in CLI.ml,
 * which is what mini-hoc -h prints (-h and --help are not hoc's flags).
 *
 * Each input is read a line at a time (for a statement in braces, all
 * its lines), and each line is run when it is read. An error is
 * reported with the input's line. After it, the input goes on at a
 * terminal, but stops there if it is a file: that is hoc.y's
 * execerror, which seeks to the end. hoc's status is always 0.
 *
 * Not hoc's:
 * - hoc's limits on a program's size (2000 instructions for all the
 *   functions) and on the stack's depth are not here, because the
 *   trees do not have them (the limit of 99 calls inside one another
 *   is kept);
 * - an error in -e's text names -e, not a temporary file;
 * - outside a definition, a return before a token that starts no
 *   expression is a syntax error (hoc's parser reduces the return
 *   first, and says "return used outside definition");
 * - x %= 0 is an error (the C divides integers by 0).
 * And hoc's bug is not here: a return alone under an if or a while
 * (bugs/goken.md). *)

type caps = < Eval.caps; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> Exit.t
