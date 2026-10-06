(* A window's text (Plan 9's rio shows a window's /dev/cons so: its
 * terminal.c; xix's Terminal): lines of characters in a rectangle of
 * an image, in one font whose characters are all as wide; what is
 * written is added at the end, and the lines move up when the
 * rectangle is full. The lines that left are kept (1,000 of them): one
 * scrolls back to them, and a bar on the left shows where what is
 * seen is among them all (rio's scroll bar). The mouse selects text. *)

type t

val make : Display.image -> Rectangle.t -> Font.t -> t
(* text added: a newline ends a line, a tab goes to the next column of 8 *)
val put : t -> string -> unit
(* the last character of the last line taken back (a backspace's) *)
val erase : t -> unit
(* what is shown moved by n lines: up (back in what was written) when
 * positive, down when negative; half of what the rectangle shows, in
 * lines (the arrow keys' step, as rio's) *)
val scroll : t -> int -> unit
val half : t -> int
(* The mouse in the text's rectangle: what it means there. A button
 * just pressed in the scroll bar scrolls, as rio's: the left one back,
 * the right one forward, by the lines the mouse is below the bar's
 * top; the middle one to that place among all the lines. The left
 * button in the text selects, from where it goes down to where the
 * mouse is until it comes up: the text selected is shown on a mark. *)
val mouse : t -> Mouse.state -> unit
(* the middle button's menu (rio's button2menu, in its terminal.c),
 * called when that button has just gone down at a point of [screen]:
 * snarf keeps the text selected (one kept for all the texts), paste
 * gives what is kept, send the same and a newline. What it gives is
 * for the caller to type in the window ("" for nothing): the line
 * being typed is the window's. *)
val menu : t -> Display.image -> Mouse.t -> Point.t -> string
(* whether a point of a text's rectangle is in its scroll bar (for the
 * window system, which keeps the buttons that are not: its menu) *)
val in_bar : Rectangle.t -> Point.t -> bool
(* all of it drawn again (a program drew over it) *)
val redraw : t -> unit
(* the same text in another rectangle, or another image (its window
 * moved, or made another size) *)
val reshape : t -> Display.image -> Rectangle.t -> t
