(* The commands on buffers and their files. This is efuns'
 * Multi_buffers, with its names. *)

(* asks for a file and shows it in the frame (C-x C-f): its buffer if
 * it has one, or else the file is read. TAB completes the name from
 * the names in its directory. *)
val load_buffer : Efuns.action

(* [open_file frame file] does the same for a file named. A directory
 * is shown by [open_directory] (Dired sets it; without Dired, a
 * directory is refused). *)
val open_file : Efuns.frame -> string -> unit
val open_directory : (Efuns.frame -> string -> unit) ref
val is_directory : Efuns.caps -> string -> bool

(* writes the frame's buffer to its file (C-x C-s), or to a file
 * asked for, which then becomes its file (C-x C-w) *)
val save_buffer : Efuns.action
val write_buffer : Efuns.action

(* asks for another buffer and shows it (C-x b). By default it is the
 * one shown before, and a name that is no buffer's makes a buffer. *)
val change_buffer : Efuns.action

(* shows the buffer shown before, without asking *)
val switch_to_other_buffer : Efuns.action

(* the ends of the names that completion does not propose (.cmo) *)
val ignored_extensions : string list ref

(* makes a buffer no longer one of the editor's (C-x k), asking again
 * if it was modified and has a file. The frames that showed it show
 * another buffer. *)
val kill_buffer : Efuns.action

(* ends the editor (C-x C-c), asking again if a file's buffer was
 * modified *)
val exit : Efuns.action
