(* The commands on buffers and their files. efuns' Multi_buffers. *)

(* the frame's buffer written to its file (C-x C-s) *)
val save_buffer : Efuns.action

(* the editor's end (C-x C-c) *)
val exit : Efuns.action
