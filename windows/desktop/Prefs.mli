(* A person's desktop settings: what settings writes, the panel and the
 * desk read, $home/lib/desktop/settings, a line a setting:
 *
 *     wallpaper=colour 3a5f85
 *     wallpaper=picture /usr/pad/lib/sea.jpg
 *     clock=24              (or 12, or off)
 *     edge=bottom           (or top: the panel's)
 *     swap=no               (the mouse's buttons, left and right)
 *     accelerated=no
 *     volume=70
 *
 * A line it does not know is left out, a setting not said is the default:
 * a file of an older or a newer desktop still reads.
 *
 * design:
 * No message between the programs: settings writes the file, and the panel
 * and the desk look at it again, the panel at its clock's second, the desk
 * every two seconds. A file is what Plan 9 has to share, and a program
 * started later finds what was said before. The mouse and the volume are the
 * kernel's: settings writes their device files at once, and at a session's
 * start (settings -apply), so that the file's word holds after a boot. *)

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

(* the file's place for that home *)
val path : string -> string

(* [clock_text t hour minute]: what the panel's clock says; "" for off *)
val clock_text : t -> int -> int -> string

(* what to write to /dev/mousectl, a line each *)
val mouse_lines : t -> string list

(* the colours settings offers, by their names *)
val colours : (string * int) list
