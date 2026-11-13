(* The mouse, when the editor is in a window (lib_terminal/hosts). A
 * click and the wheel come as keys (<mouse-1>, <wheel-up>,
 * <wheel-down>), and where the mouse is comes in the top window's
 * top_mouse. This is efuns' Mouse; the "E" is there because Mouse is
 * lib_graphics's, which the Plan 9 host is linked with. *)

(* <mouse-1>: the frame under the mouse gets the keys, and its point
 * goes to the character clicked (a click on its status line only
 * gives it the keys) *)
val mouse_set_frame : Efuns.action

(* the wheel: the frame under the mouse moves three lines up or down
 * its text *)
val mouse_scroll_up : Efuns.action
val mouse_scroll_down : Efuns.action
