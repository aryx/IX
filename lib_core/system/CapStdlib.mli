(* ix: the stdlib's functions given a capability (see Cap), the ones ix
 * uses; the capabilities ocaml-caps' (dune's) asks for, written for the
 * reader: mini-ml does not look at an object type's names *)

val exit : < Cap.exit; .. > -> int -> 'a
val open_in : < Cap.open_in; .. > -> string -> in_channel
