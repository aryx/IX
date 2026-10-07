(* mini-singml: what mini-singularity (kernel/singularity) asks of the
 * language beyond mini-ml, as a program of its own over mini-ml's
 * parser: nothing of it is in languages/ml. A contract's declaration
 * made its module, in OCaml, which mini-ml then compiles. Its usage:
 * [help] in CLI.ml, what mini-singml -h prints. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
