(* What a window says of itself to its program (rio's Qwinname,
 * Qwinid, Qlabel, Qtext, Qwindow, Qscreen, Qsnarf; xix's Virtual_draw, Dev_wm and
 * Dev_textual_window). *)

(* its image's name: where a program draws (Display.screen reads it) *)
val winname : Device.t
(* its number, as the kernel's files say numbers (11 characters and a space) *)
val winid : Device.t
(* its name in the menu when hidden: read, or written anew *)
val label : Device.t
(* its text, all the lines kept; read only *)
val text : Device.t
(* its picture, border and all, and the whole screen's, as Plan 9
 * writes an image in a file (Display.file); read only. A picture is
 * taken when the file is read from its start *)
val window : Device.t
val screen : Device.t
(* the text kept by the windows' menu (Terminal's: one for all the
 * windows), read, or written anew (opened to be written, it is empty) *)
val snarf : Device.t
