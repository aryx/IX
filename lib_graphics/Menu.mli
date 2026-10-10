(* A menu under the mouse (Plan 9's menuhit, libdraw's menuhit.c; xix's
 * lib_graphics/ui): its items one above the other in a box, the one
 * under the mouse shown, chosen when the button is let go. Its colours
 * are ix's own, blues, where Plan 9's are greens.
 *
 *     button down           moved, still down       let go
 *
 *     +----------+          +----------+
 *     |   New    |          |   New    |            Some 2
 *     |##Resize##| <- mouse |  Resize  |            (None, outside
 *     |   Move   |          |###Move###| <- mouse    the box)
 *     |  Delete  |          |  Delete  |
 *     +----------+          +----------+
 *
 * The box is placed so that the item chosen the last time is the one
 * under the mouse: doing again what was just done is a press and a
 * release with no move, and the item next to it a few pixels away.
 * The caller keeps that number, one for each of its menus.
 *
 * The menu is no window: it is drawn on the screen's image over what
 * is there, after a copy of that rectangle to an image of its own,
 * which is copied back at the end (two Draw.draw, an image as src).
 * And it is no thread: [hit] reads the mouse itself until the button
 * is up, the rest of the program waiting, which is right for a
 * second's gesture and why it is a function that gives an answer.
 * Who calls it: mini-rio, for its menu of windows at the third
 * button (Rio) and a window's own at the second (Terminal).
 *
 * design:
 * A menu where the hand is. A menu bar at the top of the screen (the
 * Macintosh, 1984) is found without looking, and is a trip from
 * where the work is and back; a menu that comes up under the mouse
 * needs a button of its own and costs no travel and no room on the
 * screen when it is not used. Plan 9 took the second, from the Blit
 * and from Smalltalk before it, and with three buttons has two
 * menus at any place: what its programs' look comes from.
 *
 * References: menuhit(2) in Plan 9's manual (graphics' library),
 * principia's menuhit.c. *)

(* [hit screen font mouse button items last at]: called when [button]
 * (1, 2 or 4) has just gone down, the mouse at [at]. The menu is drawn
 * with the item of number [last] under the mouse, followed until the
 * button is up, and removed (what it covered put back). The item's
 * number, or None when the mouse was let go outside. *)
val hit : Display.image -> Font.t -> Mouse.t -> int -> string list -> int -> Point.t -> int option
