(* The files in which a window tells its program about itself (rio's
 * Qwinname, Qwinid, Qlabel, Qtext, Qwindow, Qscreen, Qsnarf; xix's
 * Virtual_draw, Dev_wm and Dev_textual_window). *)

(* the name of the window's image, which is where a program draws
 * (Display.screen reads it) *)
val winname : Device.t
(* the window's number, written as the kernel's files write numbers (11
 * characters and a space) *)
val winid : Device.t
(* the window's name in the menu when it is hidden; it can be read, or
 * written anew *)
val label : Device.t
(* the window's text, with all the lines it keeps; it is read only *)
val text : Device.t
(* a picture of the window, border and all, and one of the whole
 * screen, as Plan 9 writes an image in a file (Display.file). They are
 * read only. A picture is taken when the file is read from its start. *)
val window : Device.t
val screen : Device.t
(* the text kept by the windows' menu (Terminal's, one for all the
 * windows). It can be read, or written anew: a file opened to be
 * written is emptied first. *)
val snarf : Device.t
