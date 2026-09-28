(* mini-ml's command line: [help] in CLI.ml, what mini-ml -h prints. A
 * .mli is only parsed; an error on stderr, and the exit status 1. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
