(* A window's text (Plan 9's rio shows a window's /dev/cons so: its
 * terminal.c; xix's Terminal): lines of characters in a rectangle of
 * an image, in one font whose characters are all as wide; what is
 * written is added at the end, and the lines move up when the
 * rectangle is full. No scrolling back, no selection yet. *)

type t

val make : Display.image -> Rectangle.t -> Font.t -> t
(* text added: a newline ends a line, a tab goes to the next column of 8 *)
val put : t -> string -> unit
(* the last character of the last line taken back (a backspace's) *)
val erase : t -> unit
(* all of it drawn again (a program drew over it) *)
val redraw : t -> unit
