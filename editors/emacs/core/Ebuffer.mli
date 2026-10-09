(* A buffer: a text, the file it is of (or none), its keys and its
 * modes. efuns' Ebuffer; "E" as Buffer is the standard library's. *)

(* the mode of a buffer that has no other *)
val fundamental_mode : Efuns.major_mode

(* [create name filename text]: a buffer of the editor's, its name
 * made its own (a second foo.ml is foo.ml<2>) *)
val create : string -> string option -> Text.t -> Efuns.buffer

val find_buffer_opt : string -> Efuns.buffer option

(* the buffer of a file: the one that has it already, or the file
 * read; a file that is not there is an empty buffer, made when saved *)
val read : < Cap.open_in ; .. > -> string -> Efuns.buffer

(* written to its file; Failure if it has none, Sys_error if it
 * cannot be *)
val save : < Cap.open_out ; .. > -> Efuns.buffer -> unit

(* changed since it was read or saved *)
val modified : Efuns.buffer -> bool
