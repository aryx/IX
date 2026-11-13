(* A person's desktop settings, which settings writes and the panel and
 * the desk read. They are in $home/lib/desktop/settings, one line per
 * setting:
 *
 *     wallpaper=colour 3a5f85
 *     wallpaper=picture /usr/pad/lib/sea.jpg
 *     clock=24              (or 12, or off)
 *     edge=bottom           (or top: the panel's side)
 *     swap=no               (the mouse's buttons, left and right)
 *     accelerated=no
 *     volume=70
 *
 * A line it does not know is left out, and a setting that is not given
 * gets the default, so a file of an older or a newer desktop can still
 * be read.
 *
 * design:
 * There is no message between the programs. settings writes the file,
 * and the panel and the desk look at it again, the panel at each second
 * of its clock and the desk every two seconds. A file is what Plan 9 has
 * to share, and a program started later finds what was said before. The
 * mouse and the volume belong to the kernel: settings writes their
 * device files at once, and again at a session's start (settings
 * -apply), so that what the file says holds after a boot. *)

type wallpaper = Colour of int | Picture of string

type t = {
  wallpaper : wallpaper;
  clock : string;
  edge : string;
  swap : bool;
  accelerated : bool;
  volume : int option;
}

val default : t
val parse : string -> t
val print : t -> string

(* where the file is, for that home directory *)
val path : string -> string

(* [clock_text t hour minute] is what the panel's clock says, or "" when
 * the clock is off *)
val clock_text : t -> int -> int -> string

(* the lines to write to /dev/mousectl, one per write *)
val mouse_lines : t -> string list

(* the colours settings offers, by their names *)
val colours : (string * int) list
