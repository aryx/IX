(* mini-pascal: Pascal compiled to P-code and run on a P-machine
 * (docs/plans/plan_pascal.md), on a terminal: a program compiled and
 * run, its readln answered by the lines typed; or its P-code listed.
 * TinyTurboPascal is the same compiler and machine in an IDE.
 * Its usage: [help] in CLI.ml, what mini-pascal -h prints. *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
