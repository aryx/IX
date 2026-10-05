
val with_open_in : 
  <Cap.open_in; ..> -> (Chan.i -> 'a) -> Fpath.t -> 'a
val with_open_out : 
  <Cap.open_out; ..> -> (Chan.o -> 'a) -> Fpath.t -> 'a

(* ix: Unix.openfile given the capability, to read, or to read and
 * write (a 9P server's file, for mount); Unix_error when it fails *)
val open_in_fd : <Cap.open_in; ..> -> string -> Unix.file_descr
val open_rw_fd : <Cap.open_in; Cap.open_out; ..> -> string -> Unix.file_descr

val cat : <Cap.open_in; ..> -> Fpath.t -> string list

(* use Cap.open_out as removing a file is similar to erasing/overwriting
 * its content.
 *)
val remove: <Cap.open_out; ..> -> Fpath.t -> unit
