(* mini-datalog: Datalog (docs/plans/plan_prolog.md) on a terminal:
 * files of facts and rules, run to their fixpoint, queries answered.
 * Its usage: [help] in CLI.ml, what mini-datalog -h prints. *)

type caps = < Cap.open_in; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
