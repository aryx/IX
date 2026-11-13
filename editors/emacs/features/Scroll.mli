(* The commands that move the frame over its text. This is efuns'
 * Scroll. *)

(* move a screen down the text (C-v) or up (M-v), with two of its
 * lines still shown. If the point is no longer shown, it goes to the
 * first line shown or to the last. *)
val forward_screen : Efuns.action
val backward_screen : Efuns.action

(* move a line down the text, or a line up *)
val scroll_up : Efuns.action
val scroll_down : Efuns.action

(* puts the point's line in the frame's middle (C-l) *)
val recenter : Efuns.action
