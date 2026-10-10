(* mini-prolog: Prolog (docs/plans/plan_prolog.md) on a terminal: files
 * consulted, goals run, a prompt. Its usage: [help] in CLI.ml, what
 * mini-prolog -h prints. *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
