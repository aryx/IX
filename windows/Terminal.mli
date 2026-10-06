(* A window's text (Plan 9's rio shows a window's /dev/cons so: its
 * terminal.c; xix's Terminal): lines of characters in a rectangle of
 * an image, in one font whose characters are all as wide; what is
 * written is added at the end, and the lines move up when the
 * rectangle is full. The lines that left are kept (1,000 of them): one
 * scrolls back to them, and a bar on the left shows where what is
 * seen is among them all (rio's scroll bar). No selection yet. *)

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
(* The mouse: a button just pressed in the text's rectangle. In the
 * scroll bar it scrolls, as rio's: the left button back, the right
 * one forward, by the lines the mouse is below the bar's top; the
 * middle one to that place among all the lines. *)
val pressed : t -> Mouse.state -> unit
(* whether a point of a text's rectangle is in its scroll bar (for the
 * window system, which keeps the buttons that are not: its menu) *)
val in_bar : Rectangle.t -> Point.t -> bool
(* all of it drawn again (a program drew over it) *)
val redraw : t -> unit
(* the same text in another rectangle, or another image (its window
 * moved, or made another size) *)
val reshape : t -> Display.image -> Rectangle.t -> t
