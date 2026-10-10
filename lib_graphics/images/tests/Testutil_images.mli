(* What the pictures' tests share: how a file of the tests' data
 * (pngsuite/, jpegs/, ours/) is read, by its name there; set by Test,
 * which has the capabilities. *)

val reader : (string -> string) ref
