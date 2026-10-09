(* TinyLib: lib_core/commons/FS, the part the tiny programs call (tiny/TinyLib/README.md) *)


(* ix: Unix.openfile given the capability, to read, or to read and
 * write (a 9P server's file, for mount); Unix_error when it fails *)

(* ix: a file made, or emptied, to be written, with these permissions
 * when it is made; a directory made; a file or an empty directory
 * removed; the directory the process is in. Unix_error when they fail. *)

(* ix: whole files in and out, through the capabilities to open them
 * (ix's Files, merged here): shared by the assembler, linker,
 * compilers, builder and shell. *)

(* the whole file (a pipe too); Sys_error if it cannot be read *)
val read : < Cap.open_in; .. > -> Fpath.t -> string
(* None if it cannot be opened *)
val write : < Cap.open_out; .. > -> Fpath.t -> string -> unit
(* the same, created with a mode: 0o755 for an executable *)
val write_perm : < Cap.open_out; .. > -> int -> Fpath.t -> string -> unit
(* a path from the command line; Error for "" (Fpath's only refusal
 * besides a NUL) *)

(* ix: libc's cleanname (Plan 9's): a name without its empty and "."
 * parts, and without the ".." a name before them answers; no file is
 * looked at *)
val cleanname : string -> string


(* use Cap.open_out as removing a file is similar to erasing/overwriting
 * its content.
 *)
