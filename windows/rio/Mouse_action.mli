(* What the mouse does for the window manager once a menu's item is
 * chosen, or a border is pressed (rio's wm.c: sweep, pointto, drag,
 * bandsize; xix's Mouse_action). Each function reads the mouse itself
 * until the buttons are up, and returns a rectangle or a window. The
 * cursor tells which one is asked for. *)

type t

(* (the desktop is where the rectangle being swept is shown) *)
val make : < Cap.mouse; .. > -> Mouse.t -> Display.t -> Display.desktop -> t

(* a rectangle swept out with the right button, with a cross as the
 * cursor: it goes from where the button goes down to where it comes
 * up, and it is shown as it grows (rio's way: a pale window with a red
 * border) *)
val sweep : t -> Rectangle.t
(* a window pointed at with the right button, with a sight as the
 * cursor *)
val point : t -> Window.t option
(* a window dragged with the right button, its outline following the
 * mouse: returns the window, and where it is let go *)
val drag : t -> (Window.t * Rectangle.t) option
(* [grab a w which m]: a button was pressed (m) on a window's border,
 * at the corner or side [which] (as Wm.border gives it). With the left
 * or the middle button, that corner or side follows the mouse while
 * the others stay (rio's bandsize). With the right one, the window
 * follows the mouse, with a box as the cursor (rio's drag). The window
 * gets its new rectangle if it is another one and it fits. *)
val grab : t -> Window.t -> int -> Mouse.state -> unit
(* the mouse moved with no button down: shows the cursor of the
 * border's corner or side it is on, else the one of the window it is
 * in (its program's), else the arrow. rio shows the cursor of the
 * window that has the keyboard, wherever the mouse is. *)
val hover : t -> Mouse.state -> unit
