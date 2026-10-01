(* ix: fmt (Daniel Bünzli's library), the two names ix's programs use,
 * for mini-ml (dune's builds take the real library): Format's, under
 * shorter names. *)

val pf : Format.formatter -> ('a, Format.formatter, unit) format -> 'a
val stderr : Format.formatter
