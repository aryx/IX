(* The commands on buffers and their files. efuns' Multi_buffers, and
 * its names. *)

(* a file asked and shown in the frame (C-x C-f): its buffer if it has
 * one, or read; TAB completes the name from its directory's *)
val load_buffer : Efuns.action

(* [open_file frame file]: the same of a file named; a directory is
 * [open_directory]'s to show (Dired sets it; without: refused) *)
val open_file : Efuns.frame -> string -> unit
val open_directory : (Efuns.frame -> string -> unit) ref
val is_directory : Efuns.caps -> string -> bool

(* the frame's buffer written to its file (C-x C-s), or to a file
 * asked, which is then its own (C-x C-w) *)
val save_buffer : Efuns.action
val write_buffer : Efuns.action

(* another buffer asked and shown (C-x b): by default the one shown
 * before; a name that is no buffer's makes one *)
val change_buffer : Efuns.action

(* the one shown before, not asked *)
val switch_to_other_buffer : Efuns.action

(* the ends of the names that completion does not propose (.cmo) *)
val ignored_extensions : string list ref

(* a buffer no longer the editor's (C-x k), asked again if it was
 * modified; the frames that showed it show another *)
val kill_buffer : Efuns.action

(* the editor's end (C-x C-c), asked again if a file's buffer was
 * modified *)
val exit : Efuns.action
