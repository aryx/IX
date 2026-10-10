(* ix: files, through the capabilities to open them (xix's FS, and
 * ix's additions, each under its own comment below). Every access
 * to the file system that a program of ix makes goes by a function
 * here, which asks for Cap.open_in, Cap.open_out or Cap.readdir: so
 * a signature says whether a function may read files, write them,
 * or neither (Cap). Three levels, by what the caller needs:
 *
 *     read, write, cat          a whole file as a string, or its lines
 *     with_open_in, _out        a channel with its origin (Chan),
 *                               closed whatever happens
 *     open_in_fd, create_fd...  a descriptor: Unix.openfile's, for a
 *                               program that says the system's reason
 *                               when it fails, or serves a file
 *
 * A path is an Fpath.t where xix had one, a string where the
 * system's own name is passed on as the user typed it. *)

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
(* (a new file, empty, which must not be there) *)
val create_fd : <Cap.open_out; ..> -> string -> Unix.file_perm -> Unix.file_descr
(* (a file to be written at its end, made when it is not there) *)
val open_append_fd : <Cap.open_out; ..> -> string -> Unix.file_perm -> Unix.file_descr
val mkdir : <Cap.open_out; ..> -> string -> Unix.file_perm -> unit
val remove_any : <Cap.open_out; ..> -> string -> unit
val getcwd : <Cap.readdir; ..> -> unit -> string

(* ix: whole files in and out, through the capabilities to open them
 * (ix's Files, merged here): shared by the assembler, linker,
 * compilers, builder and shell. *)

(* the whole file (a pipe too); Sys_error if it cannot be read *)
val read : < Cap.open_in; .. > -> Fpath.t -> string
(* None if it cannot be opened *)
val read_opt : < Cap.open_in; .. > -> Fpath.t -> string option
(* created (0o644) or truncated *)
val write : < Cap.open_out; .. > -> Fpath.t -> string -> unit
(* the same, created with a mode: 0o755 for an executable *)
val write_perm : < Cap.open_out; .. > -> int -> Fpath.t -> string -> unit
(* a path from the command line; Error for "" (Fpath's only refusal
 * besides a NUL) *)
val path : string -> (Fpath.t, string) result

(* ix: libc's cleanname (Plan 9's): a name without its empty and "."
 * parts, and without the ".." a name before them answers; no file is
 * looked at *)
val cleanname : string -> string

val cat : <Cap.open_in; ..> -> Fpath.t -> string list

(* use Cap.open_out as removing a file is similar to erasing/overwriting
 * its content.
 *)
val remove: <Cap.open_out; ..> -> Fpath.t -> unit
