(* The input and the preprocessor: files and macro expansions pushed
 * on one stack, which the lexer reads a character at a time ([getc]),
 * the directives handled as the lexer meets a '#' (lex.c's Io; macbody).
 *
 * There is no separate pass: an #include pushes the file, a macro's
 * use pushes its expansion, and each pops when exhausted. A macro is
 * stored in its symbol's [macro], its body's parameters already replaced
 * by their index, #a, #b... (5c's encoding: the expansion needs no parsing).
 *
 *     #define MAX(a, b) ((a) > (b) ? (a) : (b))
 *     #define N 10
 *     int f(int i) { return MAX(i, N); }
 *
 *     MAX's symbol   macro = "((#a) > (#b) ? (#a) : (#b))", after a
 *                    first character that says two arguments
 *     at MAX(        the lexer finds a macro: [macexpand] reads i and
 *                    N up to the parenthesis, and its result is pushed:
 *
 *        the stack, top first        what the lexer reads next
 *        ((i) > (N) ? (i) : (N))     tokens as any others, until N,
 *        ; }  and the rest of f.c    a macro too: 10 is pushed over it
 *
 * So an expansion is scanned again for macros because it is input
 * again, with no rule written for it, and the parser sees i > 10 ?
 * i : 10 without knowing a macro was there.
 *
 * cs-history:
 * C had no preprocessor at first. Dennis Ritchie dates it to 1972
 * or 1973, prompted by Alan Snyder and by the file inclusion of
 * BCPL and PL/I: at first #include and #define without parameters
 * only, then, by Mike Lesk and John Reiser, macros with arguments
 * and conditional compilation. It stayed a program of its own, cpp,
 * a text to a text, knowing nothing of C, which is why a macro can
 * break the language's syntax and a compiler's error may name code
 * the programmer never wrote.
 *
 * plan9-is-cleaner:
 * Less of it. The built-in preprocessor has #include, #define,
 * #undef, #ifdef, #ifndef, #else, #endif, #line and #pragma, and no
 * #if: a condition is at most a name defined or not. Plan 9's
 * sources do not need more because its headers do not test the
 * machine or the compiler (one compiler, one libc, the machine's
 * types in a u.h found by the include path), and by its convention
 * a header includes no other header, so none needs the #ifndef
 * guard of every Unix header; a .c file lists what it needs, in
 * order. (In Plan 9 a header's #pragma lib names its library for
 * the linker; here only #pragma profile reaches the code.)
 *
 * References: Ken Thompson, "Plan 9 C Compilers", section "Parsing":
 * "The input stream of the parser is a pushdown list of input
 * activations. The preprocessor expansions of macros and #include are
 * implemented as pushdowns. Thus there is no separate pass for
 * preprocessing.", and "The preprocessor", for what is left out;
 * Dennis Ritchie, "The Development of the C Language" (HOPL-II,
 * 1993), for the preprocessor's beginnings; Rob Pike, "Notes on
 * Programming in C" (1989), "Include files", for the rule that a
 * header includes no header. *)

val includes : Fpath.t list ref

(* the character put back, if any *)
val peekc : char option ref

(* the end of the input: a NUL is no C *)
val eof : char

(* the next byte, eof at the end *)
val raw : unit -> char

(* the text, read next *)
val push : string -> unit

(* the character put back, or the next *)
val read : unit -> char

(* the next, counting lines; an error at the end *)
val getc : unit -> char

val unget : char -> unit

val is_alpha : char -> bool
val is_digit : char -> bool
val is_alnum : char -> bool
val is_space : char -> bool

(* -Dname=value *)
val dodefine : string -> unit

(* the expansion of a use of s, its arguments read *)
val macexpand : Tree.sym -> string

(* how #include reads a file, set by CLI (with its capability) *)
val read_file : (Fpath.t -> string option) ref

(* #pragma profile's: whether TEXT gets NOPROF *)
val profile : bool ref

(* the directive after a '#' *)
val domacro : unit -> unit
