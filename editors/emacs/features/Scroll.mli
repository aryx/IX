(* The commands that move the frame over its text. efuns' Scroll. *)

(* a screen down the text (C-v) or up (M-v), two of its lines still
 * shown; the point, if it is no longer shown, to the first line shown
 * or to the last *)
val forward_screen : Efuns.action
val backward_screen : Efuns.action

(* a line down the text, a line up *)
val scroll_up : Efuns.action
val scroll_down : Efuns.action

(* the point's line in the frame's middle (C-l) *)
val recenter : Efuns.action
