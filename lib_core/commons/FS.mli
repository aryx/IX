
val with_open_in : 
  <Cap.open_in; ..> -> (Chan.i -> 'a) -> Fpath.t -> 'a
val with_open_out : 
  <Cap.open_out; ..> -> (Chan.o -> 'a) -> Fpath.t -> 'a

(* ix: Unix.openfile given the capability, to read, or to read and
 * write (a 9P server's file, for mount); Unix_error when it fails *)
val open_in_fd : <Cap.open_in; ..> -> string -> Unix.file_descr
val open_rw_fd : <Cap.open_in; Cap.open_out; ..> -> string -> Unix.file_descr

(* ix: a file made, or emptied, to be written, with these permissions
 * when it is made; a directory made; a file or an empty directory
 * removed; the directory the process is in. Unix_error when they fail. *)
val open_out_fd : <Cap.open_out; ..> -> string -> Unix.file_perm -> Unix.file_descr
val mkdir : <Cap.open_out; ..> -> string -> Unix.file_perm -> unit
val remove_any : <Cap.open_out; ..> -> string -> unit
val getcwd : <Cap.readdir; ..> -> unit -> string

val cat : <Cap.open_in; ..> -> Fpath.t -> string list

(* use Cap.open_out as removing a file is similar to erasing/overwriting
 * its content.
 *)
val remove: <Cap.open_out; ..> -> Fpath.t -> unit
