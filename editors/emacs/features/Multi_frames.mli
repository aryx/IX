(* The commands on windows: the screen shared by several frames.
 * efuns' Multi_frames, and its names. *)

(* the frame's window made two, one over the other (C-x 2) or side by
 * side (C-x 3): a second frame on the same buffer, at the same place *)
val vertical_cut_frame : Efuns.action
val horizontal_cut_frame : Efuns.action

(* the keys to the next frame (C-x o) *)
val next_frame : Efuns.action

(* the frame's window gone, its place the window's beside it (C-x 0);
 * every window but the frame's (C-x 1) *)
val delete_frame : Efuns.action
val one_frame : Efuns.action
