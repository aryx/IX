(* TinyLib: lib_core/commons/FS, the part the tiny programs call (tiny/TinyLib/README.md) *)

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
