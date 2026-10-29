(* mini-acid: Plan 9's acid (principia's debuggers/acid), a debugger
 * that is a language: C's expressions and statements, lists and
 * strings, functions (defn), and builtins that read a stopped
 * process's memory and registers by its /proc. What a debugger does
 * (a stack trace, a breakpoint, a step) is a function written in acid,
 * in a library read at the start (port.acid, arm.acid), so that a user
 * adds to the debugger as to the library.
 *
 *     acid: defn fact(n) { if n <= 1 then return 1; return n*fact(n-1); }
 *     acid: fact(10)
 *     0x00375f00
 *     acid: fact(10)\D
 *     3628800
 *
 * A top-level statement's way through the modules:
 *
 *     Lexer --> Parser --> Ast --> Eval --> what is printed
 *     acid's    a statement      | Value: the values, their formats
 *     tokens                     | Builtin: print, fmt, atoi...
 *
 * A value carries a format, a letter (X, D, s, a...) that says how it
 * prints and how big it is in memory; a result takes its left
 * operand's, so a pointer stays one through arithmetic (Value.mli).
 * The variables are dynamically scoped (Eval.mli).
 *
 * This step (plan_debugger.md, stage 8, step 3): the language and its
 * builtins; the process (the memory's *, @ and [], complex types' . and
 * casts, the registers, start, stop, the symbols as variables, the
 * libraries) is step 4's. Not yet: floats printed as Plan 9's %g.
 *
 * cs-history:
 * acid is Phil Winterbottom's, for Plan 9's second edition (1995),
 * "Acid: A Debugger Built From A Language" (USENIX Winter 1994): a
 * debugger's commands are a language's functions, so the library
 * grows the debugger (a trace of a program's calls, a leak checker,
 * the kernel's own structures), where dbx and gdb grew commands in C.
 * gdb's Python (2009) and lldb's are the same idea, decades later.
 *
 * References: acid(1) in the Plan 9 manual; Winterbottom's paper and
 * "Acid Manual"; principia's Debugger.nw. *)

type caps = < Builtin.caps; Cap.stdin; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> Exit.t
