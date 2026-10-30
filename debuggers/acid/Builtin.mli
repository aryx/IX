(* acid's builtin functions (principia's builtin.c), those of the
 * language: print, fmt, fmtof, fmtsize, atoi, atof, itoa, error,
 * access, readfile, file, match. A builtin gets its arguments' values;
 * a function of acid's of the same name hides it, but for builtin
 * f(...). The process's (start, stop, strace...) are Proc's. *)

type caps = < Cap.open_in >

(* the builtins put in Eval.builtins *)
val init : < caps; .. > -> unit
