(* The command line: its usage and a few examples are [help] in CLI.ml,
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
