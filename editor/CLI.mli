(* mini-ed's command line, ed's: its usage and options are [help] in
 * CLI.ml, what mini-ed -h prints (-h and --help, not ed's).
 *
 * An interrupt prints ? and goes back to the commands; a hangup writes
 * the buffer to ed.hup and quits. The exit status is 0, as ed.c's. *)

type caps = < Command.caps; Cap.argv; Cap.exit; Cap.stdout >

val main : < caps; .. > -> string array -> int
