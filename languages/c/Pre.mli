(* The input and the preprocessor. Files and macro expansions are
 * pushed on one stack, which the lexer reads a character at a time
 * ([getc]), and the directives are handled when the lexer meets a '#'
 * (lex.c's Io; macbody).
 *
 * There is no separate pass: an #include pushes the file, the use of a
 * macro pushes its expansion, and each is popped when exhausted. A
 * macro is stored in its symbol's [macro], with the parameters of its
 * body already replaced by their index, #a, #b... This is 5c's
 * encoding, and with it the expansion needs no parsing.
 *
 *     #define MAX(a, b) ((a) > (b) ? (a) : (b))
 *     #define N 10
 *     int f(int i) { return MAX(i, N); }
 *
 *     MAX's symbol   macro = "((#a) > (#b) ? (#a) : (#b))", after a
 *                    first character that says there are two arguments
 *     at MAX(        the lexer finds a macro: [macexpand] reads i and
 *                    N up to the parenthesis, and its result is pushed:
 *
 *        the stack, top first        what the lexer reads next
 *        ((i) > (N) ? (i) : (N))     tokens like any others, until N,
 *        ; }  and the rest of f.c    a macro too, so 10 is pushed over it
 *
 * So an expansion is scanned again for macros because it is input
 * again, with no rule written for it, and the parser sees i > 10 ?
 * i : 10 without knowing a macro was there.
 *
 * cs-history:
 * C had no preprocessor at first. Dennis Ritchie dates it to 1972
 * or 1973, prompted by Alan Snyder and by the file inclusion of
 * BCPL and PL/I. At first it had only #include, and #define without
 * parameters; then Mike Lesk and John Reiser added macros with
 * arguments and conditional compilation. It stayed a program of its
 * own, cpp, which turns a text into a text and knows nothing of C.
 * That is why a macro can break the language's syntax, and why a
 * compiler's error may name code that the programmer never wrote.
 *
 * plan9-is-cleaner:
 * There is less of it. The built-in preprocessor has #include,
 * #define, #undef, #ifdef, #ifndef, #else, #endif, #line and #pragma,
 * and no #if: a condition can only ask whether a name is defined.
 * Plan 9's sources do not need more, because its headers do not test
 * the machine or the compiler: there is one compiler and one libc, and
 * the machine's types are in a u.h found by the include path. And by
 * Plan 9's convention a header includes no other header, so none needs
 * the #ifndef guard that every Unix header has; a .c file lists what
 * it needs, in order. (In Plan 9, a header's #pragma lib names its
 * library for the linker; here only #pragma profile reaches the code.)
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

(* the character that ends the input: a NUL, which is never C *)
val eof : char

(* the next byte, or eof at the end *)
val raw : unit -> char

(* pushes a text to be read next (a macro's expansion) *)
val push : string -> unit

(* pushes a file's text to be read next, and records its start in the
 * history; its end is recorded too, when it is read through *)
val push_file : string -> string -> unit

(* how many files are being read: 1 in the file compiled, more inside
 * an #include (for Acid's -aa) *)
val depth : unit -> int

(* the files read, as 5c's history: (Some name, the global line where
 * it starts) and (None, the line after its end), the last first. It
 * goes into the object, and from there into mini-ld's z entries (see
 * Symbols's fline). *)
val history : (string option * int) list ref

(* the character put back, if any, or else the next one *)
val read : unit -> char

(* the next character, counting lines; an error at the end *)
val getc : unit -> char

val unget : char -> unit

val is_alpha : char -> bool
val is_digit : char -> bool
val is_alnum : char -> bool
val is_space : char -> bool

(* -Dname=value *)
val dodefine : string -> unit

(* the expansion of a use of s, after reading its arguments *)
val macexpand : Tree.sym -> string

(* how #include reads a file, set by CLI (with its capability) *)
val read_file : (Fpath.t -> string option) ref

(* set by #pragma profile: whether the functions are profiled. When it
 * is false, TEXT gets NOPROF. *)
val profile : bool ref

(* handles the directive after a '#' *)
val domacro : unit -> unit
