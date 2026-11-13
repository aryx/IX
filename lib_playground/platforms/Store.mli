(* The platforms' store of documents, which are saved and opened
 * again. The documents are named, each one is a string of bytes (what
 * apps/office's Saved writes), and they are the files of one
 * directory. A name is the document's own ("budget.sheet"); a '/' in
 * it is not a directory. One module serves every platform, and it is
 * synchronous, so an update can call it as it goes.
 *
 * ix: the playground's playground/platforms/native_common/Store takes
 * no capability (its platform is trusted, and only the types of the
 * wrappers mention one). Here each function is given the capabilities
 * of what it does, and does it through them (FS, Sys_plan9, CapSys):
 * it reads the environment for the directory's name, reads a file,
 * writes one, or lists a directory. *)

(* the directory: $PLAYGROUND_STORE, or $HOME/.ix-playground/documents,
 * or on Plan 9 $home/lib/documents, or documents in the current
 * directory with none of them *)
val dir : < Cap.env ; .. > -> string

(* (store makes the directory if it is missing) *)
val store : < Cap.env ; Cap.open_out ; .. > -> string -> string -> unit
val fetch : < Cap.env ; Cap.open_in ; .. > -> string -> string option

(* the names, in order; none when there is no directory yet *)
val stored : < Cap.env ; Cap.readdir ; .. > -> string list

(* writes a file in the current directory *)
val export : < Cap.open_out ; .. > -> string -> string -> unit
