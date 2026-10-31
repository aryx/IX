(* What the mouse does for the window manager once a menu's item is
 * chosen, or a border pressed (rio's wm.c: sweep, pointto, drag,
 * bandsize; xix's Mouse_action): each reads the mouse itself until
 * the buttons are up, and says a rectangle or a window. The cursor
 * tells which is asked. *)

type t

(* (the desktop is where the rectangle being swept is shown) *)
val make : < Cap.mouse; .. > -> Mouse.t -> Display.t -> Display.desktop -> t

(* a rectangle swept out with the right button, the cursor a cross:
 * from where the button goes down to where it comes up, shown as it
 * grows (rio's: a pale window with a red border) *)
val sweep : t -> Rectangle.t
(* a window pointed at with the right button, the cursor a sight *)
val point : t -> Window.t option
(* a window dragged with the right button, its outline following the
 * mouse: the window, and where it is let go *)
val drag : t -> (Window.t * Rectangle.t) option
(* [grab a w which m]: a button was pressed (m) on a window's border,
 * at the corner or side [which] (Wm.border's). The left or the middle
 * one: that corner or side follows the mouse, the others staying (rio's
 * bandsize); the right one: the window follows it, the cursor a box
 * (rio's drag). The window's new rectangle, if it is another and fits *)
val grab : t -> Window.t -> int -> Mouse.state -> unit
(* the mouse moved, no button down: the cursor of the border's corner
 * or side it is on, else the one of the window it is in (its
 * program's), else the arrow. rio shows the cursor of the window that
 * has the keyboard, wherever the mouse is *)
val hover : t -> Mouse.state -> unit
