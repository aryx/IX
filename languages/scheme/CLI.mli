(* mini-scheme: a small Scheme and How to Design Programs' Beginning
 * Student (docs/plans/plan_scheme.md), on a terminal: files run,
 * expressions evaluated, a prompt, the stepper's steps printed. No
 * window: big-bang's worlds and the images drawn are TinyDrScheme's.
 * Its usage: [help] in CLI.ml, what mini-scheme -h prints. *)

type caps = < Cap.open_in; Cap.stdin; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
