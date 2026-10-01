(* ix: capabilities, erased, for mini-ml (dune's builds take xix's caps
 * library; this directory is not dune's). There a function says what it
 * may do by its parameter's type, an object's, < Cap.stdout; Cap.open_in;
 * .. >, and the compiler checks it. mini-ml has no objects: every such
 * type is one type (Scope's "< .. >"), its methods' names not looked at,
 * as ocaml-light does. So the capabilities are still passed and written
 * in the types, for the reader and for OCaml, and not checked here. *)

(* all of them: main's *)
type all_caps = < >

(* f on the program's capabilities *)
val main : (all_caps -> 'a) -> 'a
