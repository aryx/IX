(* acid's builtin functions (principia's builtin.c), those of the
 * language: print, fmt, fmtof, fmtsize, atoi, atof, itoa, error,
 * access, readfile. A builtin gets its arguments' values; a function
 * of acid's of the same name hides it, but for builtin f(...). The
 * process's (start, stop, mem's formats...) are a later step's
 * (plan_debugger.md, stage 8). *)

type caps = < Cap.open_in >

(* the builtins put in Eval.builtins *)
val init : < caps; .. > -> unit
