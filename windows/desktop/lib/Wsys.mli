(* The windows rio says there are, and the line a program writes to ask
 * rio something: this is what the panel and expose share. Taskbar says
 * what a window's files mean; this module reads them, from /dev/wsys,
 * the directory of the windows that rio gives each window (rio(1)). *)

(* the windows, in the order of their numbers; a window that goes away
 * while they are read is left out *)
val windows : < Cap.readdir; Cap.open_in; .. > -> Taskbar.window list

(* a window's image's name, for Display.named *)
val winname : < Cap.open_in; .. > -> int -> string option

(* writes a line to this window's wctl, one command per write; when it
 * is refused, nothing is said *)
val ask : < Cap.open_out; .. > -> string -> unit
