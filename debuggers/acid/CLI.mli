(* mini-acid: Plan 9's acid (principia's debuggers/acid), a debugger
 * that is a language. The language has C's expressions and
 * statements, lists and strings, functions (defn), and builtins that
 * read a stopped process's memory and registers through its /proc.
 * What a debugger does (a stack trace, a breakpoint, a step) is a
 * function written in acid, in a library read at the start (port.acid,
 * arm.acid), so that a user extends the debugger by adding to the
 * library.
 *
 *     acid: defn fact(n) { if n <= 1 then return 1; return n*fact(n-1); }
 *     acid: fact(10)
 *     0x00375f00
 *     acid: fact(10)\D
 *     3628800
 *
 * Here is the way a top-level statement goes through the modules:
 *
 *     Lexer --> Parser --> Ast --> Eval --> what is printed
 *     acid's    a statement      | Value: the values, their formats
 *     tokens                     | Builtin: print, fmt, atoi...
 *
 * A value carries a format, a letter (X, D, s, a...) that says how it
 * prints and how big it is in memory. A result takes the format of its
 * left operand, so a pointer stays a pointer through arithmetic
 * (Value.mli). The variables are dynamically scoped (Eval.mli).
 *
 * Proc (step 4) handles the program and the process: the symbols as
 * variables, the memory and the registers through /proc, start, stop,
 * breakpoints, and strace (libmach's risctrace). The library is ix's
 * own (lib/port.acid, lib/arm.acid and lib/arm64.acid have acid's
 * essentials, with one stack walk for both C's frames and mini-ml's).
 * It is read from /lib/acid or with -l, and principia's library runs
 * too. Not done yet: printing floats as Plan 9's %g does.
 *
 * cs-history:
 * Phil Winterbottom wrote acid for Plan 9's second edition (1995), and
 * described it in "Acid: A Debugger Built From A Language" (USENIX
 * Winter 1994). A debugger's commands are a language's functions, so
 * the library grows the debugger (with a trace of a program's calls, a
 * leak checker, the kernel's own structures), where dbx and gdb grew
 * commands written in C. gdb's Python (2009) and lldb's are the same
 * idea, decades later.
 *
 * References: acid(1) in the Plan 9 manual; Winterbottom's paper and
 * "Acid Manual"; principia's Debugger.nw. *)

type caps = < Builtin.caps; Proc.caps; Cap.stdin; Cap.stdout; Cap.stderr; Cap.env >

val main : < caps; .. > -> string array -> Exit.t
