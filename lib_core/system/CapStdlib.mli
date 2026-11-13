(* ix: the functions of the stdlib that ix uses, each given a capability
 * (see Cap). They ask for the capabilities that ocaml-caps (the library
 * of dune's builds) asks for. These are written for the reader, because
 * mini-ml does not look at the names in an object type. *)

val exit : < Cap.exit; .. > -> int -> 'a
val open_in : < Cap.open_in; .. > -> string -> in_channel
