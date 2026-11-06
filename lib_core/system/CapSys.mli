(* ix: Sys's functions given a capability (see Cap), the ones ix uses;
 * the capabilities ocaml-caps' (dune's) asks for, written for the
 * reader: mini-ml does not look at an object type's names *)

val argv : < Cap.argv; .. > -> string array
val getenv : < Cap.env; .. > -> string -> string
val set_signal : < Cap.signal; .. > -> int -> Sys.signal_behavior -> unit

(* the files: whether one is there, a directory, its names; one removed *)
val file_exists : < Cap.readdir; .. > -> string -> bool
val is_directory : < Cap.readdir; .. > -> string -> bool
val readdir : < Cap.readdir; .. > -> string -> string array
val remove : < Cap.open_out; .. > -> string -> unit

(* the processor time used: profiling, but a clock all the same *)
val time : < Cap.clock; .. > -> unit -> float
val getcwd : < Cap.env; .. > -> unit -> string
