(* ix: files, through the capabilities to open them (this is xix's FS,
 * plus ix's additions, each under its own comment below). Every access
 * to the file system that an ix program makes goes through a function
 * here, which asks for Cap.open_in, Cap.open_out or Cap.readdir. So a
 * function's signature says whether it may read files, write them, or
 * neither (see Cap). There are three levels, by what the caller needs:
 *
 *     read, write, cat          a whole file as a string, or its lines
 *     with_open_in, _out        a channel with its origin (Chan),
 *                               closed whatever happens
 *     open_in_fd, create_fd...  a descriptor: Unix.openfile's, for a
 *                               program that says the system's reason
 *                               when it fails, or serves a file
 *
 * A path is an Fpath.t where xix had one. It is a string where the
 * name is passed on to the system as the user typed it. *)

val with_open_in : 
  <Cap.open_in; ..> -> (Chan.i -> 'a) -> Fpath.t -> 'a
val with_open_out : 
  <Cap.open_out; ..> -> (Chan.o -> 'a) -> Fpath.t -> 'a

(* ix: Unix.openfile, given the capability, to read, or to read and
 * write (for a 9P server's file, for mount). It raises Unix_error when
 * it fails. *)
val open_in_fd : <Cap.open_in; ..> -> string -> Unix.file_descr
val open_rw_fd : <Cap.open_in; Cap.open_out; ..> -> string -> Unix.file_descr

(* ix: these functions
 *  - make a file, or empty it, to be written, with these permissions
 *    when it is made (open_out_fd);
 *  - make a directory (mkdir);
 *  - remove a file or an empty directory (remove_any);
 *  - give the directory the process is in (getcwd).
 * They raise Unix_error when they fail. *)
val open_out_fd : <Cap.open_out; ..> -> string -> Unix.file_perm -> Unix.file_descr
(* (a new, empty file, which must not already exist; it is opened for
 * reading only, since its callers, such as touch, write nothing) *)
val create_fd : <Cap.open_out; ..> -> string -> Unix.file_perm -> Unix.file_descr
(* (a file to be written at its end, made when it does not exist) *)
val open_append_fd : <Cap.open_out; ..> -> string -> Unix.file_perm -> Unix.file_descr
(* (a file that exists, written without being emptied, such as a
 * device's file, /dev/audio) *)
val open_device_fd : <Cap.open_out; ..> -> string -> Unix.file_descr
val mkdir : <Cap.open_out; ..> -> string -> Unix.file_perm -> unit
val remove_any : <Cap.open_out; ..> -> string -> unit
val getcwd : <Cap.readdir; ..> -> unit -> string

(* ix: whole files in and out, through the capabilities to open them
 * (ix's Files module, merged here). The assembler, the linker, the
 * compilers, the builder and the shell share these functions. *)

(* The whole file (a pipe too); Sys_error if it cannot be read *)
val read : < Cap.open_in; .. > -> Fpath.t -> string
(* None if it cannot be opened *)
val read_opt : < Cap.open_in; .. > -> Fpath.t -> string option
(* The file is created (0o644) or truncated *)
val write : < Cap.open_out; .. > -> Fpath.t -> string -> unit
(* The same, but the file is created with a mode: 0o755 for an
 * executable *)
val write_perm : < Cap.open_out; .. > -> int -> Fpath.t -> string -> unit
(* A path from the command line; Error for "", which is the only name
 * Fpath refuses besides one with a NUL *)
val path : string -> (Fpath.t, string) result

(* ix: libc's cleanname (Plan 9's). It removes the empty and "." parts
 * of a name, and each ".." together with the part before it that it
 * cancels. No file is looked at. *)
val cleanname : string -> string

val cat : <Cap.open_in; ..> -> Fpath.t -> string list

(* use Cap.open_out as removing a file is similar to erasing/overwriting
 * its content.
 *)
val remove: <Cap.open_out; ..> -> Fpath.t -> unit
