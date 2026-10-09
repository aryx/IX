(* The platforms' store of documents, saved and opened again: named
 * documents, each a string of bytes (what apps/office's Saved writes),
 * the files of one directory. A name is the document's own
 * ("budget.sheet"); a '/' in it is not a directory. One module for
 * every platform, synchronous: an update can call it as it goes.
 *
 * ix: the playground's playground/platforms/native_common/Store takes
 * no capability (its platform is trusted, and only the wrappers'
 * types say one); here each function is given the capabilities of
 * what it does, and does it through them (FS, Sys_plan9, CapSys): the
 * environment read for the directory's name, a file read, one
 * written, a directory listed. *)

(* the directory: $PLAYGROUND_STORE, or $HOME/.ix-playground/documents,
 * or on Plan 9 $home/lib/documents, or documents in the current
 * directory with none of them *)
val dir : < Cap.env ; .. > -> string

(* (the directory is made if missing) *)
val store : < Cap.env ; Cap.open_out ; .. > -> string -> string -> unit
val fetch : < Cap.env ; Cap.open_in ; .. > -> string -> string option

(* the names, in order; none when there is no directory yet *)
val stored : < Cap.env ; Cap.readdir ; .. > -> string list

(* a file in the current directory *)
val export : < Cap.open_out ; .. > -> string -> string -> unit
