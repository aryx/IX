(* mini-cc's command line: [help] in CLI.ml, what mini-cc -h prints *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
