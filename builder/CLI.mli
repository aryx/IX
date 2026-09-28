(* The command line: its usage and options are [help] in CLI.ml, what
 * mini-mk -h prints (-h and --help, not mk's). -i: missing intermediates
 * are always made here (Build, and the plan's decision 5); -H: see
 * Outofdate; var=value: see Mkfile.
 *
 * With no target, the targets of the first rule without % or & are
 * made. $MKFLAGS is set to the options and assignments, $MKARGS to the
 * targets; $NPROC (default 1) is how many recipes run at once, $NREP
 * (default 1) how often a metarule may repeat on a path (Graph).
 *
 * References: mk(1); principia's main.c. *)

type caps = < Recipe.caps; Cap.env; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

(* [main caps argv]: the exit status: 0, or 1 after an error *)
val main : < caps; .. > -> string array -> int
