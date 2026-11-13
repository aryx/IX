(* The commands on windows, where the screen is shared by several
 * frames. This is efuns' Multi_frames, with its names. *)

(* makes the frame's window two, one over the other (C-x 2) or side by
 * side (C-x 3). The second frame is on the same buffer, at the same
 * place. *)
val vertical_cut_frame : Efuns.action
val horizontal_cut_frame : Efuns.action

(* gives the keys to the next frame (C-x o) *)
val next_frame : Efuns.action

(* [delete_frame] removes the frame's window, and the window beside
 * it takes its place (C-x 0). [one_frame] removes every window but
 * the frame's (C-x 1). *)
val delete_frame : Efuns.action
val one_frame : Efuns.action
