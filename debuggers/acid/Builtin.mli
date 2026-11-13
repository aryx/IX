(* acid's builtin functions (principia's builtin.c) that belong to the
 * language: print, fmt, fmtof, fmtsize, atoi, atof, itoa, error,
 * access, readfile, file, match, and ix's members and var. A builtin
 * gets the values of its arguments. An acid function of the same name
 * hides it, except when called as builtin f(...). The builtins for the
 * process (start, stop, strace...) are in Proc. *)

type caps = < Cap.open_in >

(* puts the builtins in Eval.builtins *)
val init : < caps; .. > -> unit
