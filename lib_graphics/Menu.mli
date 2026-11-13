(* A menu under the mouse (Plan 9's menuhit, libdraw's menuhit.c; xix's
 * lib_graphics/ui). Its items are one above the other in a box; the
 * one under the mouse is shown, and it is chosen when the button is
 * let go. Its colours are ix's own, blues, where Plan 9's are greens.
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
 * under the mouse. Doing again what was just done is then a press and
 * a release with no move, and the item next to it is a few pixels
 * away. The caller keeps that number, one for each of its menus.
 *
 * The menu is not a window: it is drawn on the screen's image, over
 * what is there, after that rectangle is copied to an image of its
 * own, which is copied back at the end (two Draw.draw, with an image
 * as src). And it is not a thread: [hit] reads the mouse itself until
 * the button is up, while the rest of the program waits. This is right
 * for a gesture of a second, and it is why [hit] is a function that
 * gives an answer. mini-rio calls it, for its menu of windows on the
 * third button (Rio) and for a window's own menu on the second
 * (Terminal).
 *
 * design:
 * A menu where the hand is. A menu bar at the top of the screen (the
 * Macintosh, 1984) is found without looking, but it is a trip from
 * where the work is and back. A menu that comes up under the mouse
 * needs a button of its own, and costs no travel and no room on the
 * screen when it is not used. Plan 9 took the second, from the Blit and
 * from Smalltalk before it, and with three buttons it has two menus at
 * any place: this is where the look of its programs comes from.
 *
 * References: menuhit(2) in Plan 9's manual (graphics' library),
 * principia's menuhit.c. *)

(* [hit screen font mouse button items last at] is called when [button]
 * (1, 2 or 4) has just gone down, with the mouse at [at]. It draws the
 * menu with the item of number [last] under the mouse, follows the
 * mouse until the button is up, and removes the menu (putting back what
 * it covered). It returns the item's number, or None when the mouse was
 * let go outside. *)
val hit : Display.image -> Font.t -> Mouse.t -> int -> string list -> int -> Point.t -> int option
