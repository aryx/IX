(* TinyLib: lib_core/commons/FS, the part the tiny programs call (tiny/TinyLib/README.md)
 *
 * Files, through the capabilities to open them (xix's FS). Every
 * access to the file system that a tiny program makes goes by a
 * function here, which asks for Cap.open_in or Cap.open_out: so a
 * signature says whether a function may read files, write them, or
 * neither (Cap). Two levels, by what the caller needs:
 *
 *     read, write, write_perm   a whole file as a string
 *     open_in_fd, open_out_fd,  a descriptor, Unix.openfile's, for a
 *     open_rw_fd, _append_fd    program that seeks in its file
 *                               (TinyDatabase), appends to it (TinyVCS)
 *                               or gives it to a child (TinyShell)
 *
 * lib_core's has a third between them, a channel with its origin
 * (with_open_in, Chan): no tiny program calls it. *)

(* ix: Unix.openfile given the capability: to read, to read and write,
 * to write (the file made or emptied, with these permissions when it
 * is made), to write at its end; Unix_error when it fails *)
val open_in_fd : <Cap.open_in; ..> -> string -> Unix.file_descr
val open_rw_fd : <Cap.open_in; Cap.open_out; ..> -> string -> Unix.file_descr
val open_out_fd : <Cap.open_out; ..> -> string -> Unix.file_perm -> Unix.file_descr
val open_append_fd : <Cap.open_out; ..> -> string -> Unix.file_perm -> Unix.file_descr

(* ix: whole files in and out, through the capabilities to open them
 * (ix's Files, merged here): shared by the assembler, linker,
 * compilers, builder and shell. *)

(* the whole file (a pipe too); Sys_error if it cannot be read *)
val read : < Cap.open_in; .. > -> Fpath.t -> string
val write : < Cap.open_out; .. > -> Fpath.t -> string -> unit
(* the same, created with a mode: 0o755 for an executable *)
val write_perm : < Cap.open_out; .. > -> int -> Fpath.t -> string -> unit

(* ix: libc's cleanname (Plan 9's): a name without its empty and "."
 * parts, and without the ".." a name before them answers; no file is
 * looked at *)
val cleanname : string -> string
