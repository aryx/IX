(* The windows rio says there are, and the line a program writes to ask it
 * something: what the panel and expose share. Taskbar says what a window's
 * files say; this reads them, from /dev/wsys, the windows' directory rio
 * gives each window (rio(1)). *)

(* the windows, by their numbers; one gone between two reads is left out *)
val windows : < Cap.readdir; Cap.open_in; .. > -> Taskbar.window list

(* a window's image's name, for Display.named *)
val winname : < Cap.open_in; .. > -> int -> string option

(* a line written to this window's wctl, a command a write; refused, said nothing *)
val ask : < Cap.open_out; .. > -> string -> unit
