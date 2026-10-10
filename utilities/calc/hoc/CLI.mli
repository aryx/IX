(* mini-hoc: Plan 9's hoc, a calculator in floating point with
 * variables, if, while and for, and functions that may call
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
 * A line's way through the modules:
 *
 *     Input --> Lexer --> Parser --> Ast --> Eval --> what is printed
 *     the files'          a line's          |
 *     characters          tree              Symbol: the names, what
 *                                           each is now (a variable,
 *                                           a built-in, a function)
 *
 * It is a whole language in small: a lexer, a yacc grammar, a
 * symbol table and an interpreter, some 400 lines of OCaml besides
 * the grammar; one to read before the shell's (mini-rc's Eval),
 * awk's (Run) or the compilers'.
 *
 * cs-history:
 * hoc is a book's program: chapter 8, "Program Development", of
 * Kernighan and Pike's "The UNIX Programming Environment" (1984),
 * which grows it in six stages to show yacc, lex and make at work.
 * hoc1 is the four operations, computed in the grammar's actions;
 * hoc2 has variables, hoc3 names of any length and the built-in
 * functions, with a symbol table; hoc4 computes the same but by
 * compiling to a stack machine's code; hoc5 adds if and while; hoc6
 * functions, procedures and recursion (the stages, from memory). The
 * name is for "high-order calculator". Plan 9's is hoc6 a little
 * further: its functions' parameters have names, where the book's
 * are $1, $2.
 *
 * The command line: its usage and a few examples are [help] in CLI.ml,
 * what mini-hoc -h prints (-h and --help, not hoc's flags).
 *
 * Each input is read a line at a time (a statement in braces: its
 * lines), each line run when read. An error is said with the input's
 * line, and the input goes on after it at a terminal, but stops there
 * if a file: hoc.y's execerror, which seeks to the end. hoc's status is
 * always 0.
 *
 * Not hoc's: its limits on a program's size (2000 instructions for all
 * the functions) and on the stack's depth, which the trees do not have
 * (99 calls in one another is kept); an error in -e's text names -e,
 * not a temporary file; outside a definition, a return before a token
 * that starts no expression is a syntax error (hoc's parser reduces the
 * return first, and says "return used outside definition"); x %= 0 is
 * an error (the C divides integers by 0). And hoc's bug is not here: a
 * return alone under an if or a while (bugs/goken.md). *)

type caps = < Eval.caps; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> Exit.t
