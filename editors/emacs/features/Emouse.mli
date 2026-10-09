(* The mouse, where the editor is in a window (lib_terminal/hosts): a
 * click and the wheel come as keys (<mouse-1>, <wheel-up>,
 * <wheel-down>), with where the mouse is (the top window's
 * top_mouse). efuns' Mouse; "E" as Mouse is lib_graphics's, which the
 * Plan 9 host is linked with. *)

(* <mouse-1>: the frame under the mouse has the keys, and its point is
 * at the character clicked (on its status line: the keys only) *)
val mouse_set_frame : Efuns.action

(* the wheel: the frame under the mouse three lines up or down its text *)
val mouse_scroll_up : Efuns.action
val mouse_scroll_down : Efuns.action
