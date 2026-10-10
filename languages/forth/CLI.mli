(* mini-forth: Forth (Forth.mli) on a terminal: files interpreted,
 * texts given, a prompt. Its usage: [help] in CLI.ml, what
 * mini-forth -h prints. *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
