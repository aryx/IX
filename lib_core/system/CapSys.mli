(* ix: the functions of Sys that ix uses, each given a capability (see
 * Cap). They ask for the capabilities that ocaml-caps (the library of
 * dune's builds) asks for. These are written for the reader, because
 * mini-ml does not look at the names in an object type. *)

val argv : < Cap.argv; .. > -> string array
val getenv : < Cap.env; .. > -> string -> string
val set_signal : < Cap.signal; .. > -> int -> Sys.signal_behavior -> unit

(* The files: whether one exists, whether it is a directory, the names
 * in a directory, and the removal of a file. *)
val file_exists : < Cap.readdir; .. > -> string -> bool
val is_directory : < Cap.readdir; .. > -> string -> bool
val readdir : < Cap.readdir; .. > -> string -> string array
val remove : < Cap.open_out; .. > -> string -> unit

(* The processor time used so far. It is meant for profiling, but it is
 * a clock all the same. *)
val time : < Cap.clock; .. > -> unit -> float
val getcwd : < Cap.env; .. > -> unit -> string
