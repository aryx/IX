(* The screen and its console (principia's arm screen.c and
 * swconsole.c). The framebuffer has the size the firmware gives ([wid]
 * and [ht] below), because 9pi has no vgasize. On it are drawn a black frame, a
 * white window, and the window's orange title bar, " Plan 9 Console ".
 * The window shows the kernel's output (screenputs): each rune is drawn
 * in the default font on white, newline, tab and backspace are handled,
 * and the window scrolls 8 lines at a time. *)

(* makes the screen, and from now on draws the console there
 * (Machine.screen then gets all of the console's output); it does
 * nothing when there is no framebuffer *)
val init : unit -> unit

(* the screen's rectangle, once there is one *)
val rect : unit -> (int * int * int * int) option

(* [wid] and [ht] are the screen's size, asked of the firmware (on a
 * board it is the monitor's size, read by init; under an emulator it is
 * 1024 by 768). [display] is the display's own size (the word that
 * Machine.display_size returns: the monitor's mode); it is 0 before
 * init. *)
val wid : int ref
val ht : int ref
val display : int ref
