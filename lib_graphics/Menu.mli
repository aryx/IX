(* A menu under the mouse (Plan 9's menuhit, libdraw's menuhit.c; xix's
 * lib_graphics/ui): its items one above the other in a box, the one
 * under the mouse shown, chosen when the button is let go. Its colours
 * are ix's own, blues, where Plan 9's are greens. *)

(* [hit screen font mouse button items last at]: called when [button]
 * (1, 2 or 4) has just gone down, the mouse at [at]. The menu is drawn
 * with the item of number [last] under the mouse, followed until the
 * button is up, and removed (what it covered put back). The item's
 * number, or None when the mouse was let go outside. *)
val hit : Display.image -> Font.t -> Mouse.t -> int -> string list -> int -> Point.t -> int option
