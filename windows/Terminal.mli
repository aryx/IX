(* A window's text (Plan 9's rio shows a window's /dev/cons so: its
 * terminal.c; xix's Terminal): lines of characters in a rectangle of
 * an image, in one font whose characters are all as wide; what is
 * written is added at the end, and the lines move up when the
 * rectangle is full. The lines that left are kept (1,000 of them): one
 * scrolls back to them, and a bar on the left shows where what is
 * seen is among them all (rio's scroll bar). The mouse selects text.
 *
 * plan9-is-cleaner:
 * No terminal is emulated. On Unix a window for text is a program
 * that imitates a DEC VT100: what is written to it is text mixed
 * with escape sequences (move the cursor there, clear to the end of
 * the line, this colour), which programs find in a database of
 * terminals (termcap, terminfo) and use through a library (curses),
 * and the kernel has a line discipline between the two. A window
 * here understands a newline and a tab ([put]): text goes at the
 * end, and it stays, so one scrolls back, selects it and sends
 * it again. A program that wants the whole rectangle does not
 * address a cursor: it opens the mouse and draws (Virtual_mouse,
 * Dev_wm), as the editors do. So there is no vi in a Plan 9 window,
 * and no need of clear, reset or stty.
 *
 * Ours: text is added at the end only (Rio says why); rio's can be
 * edited anywhere, as a file in an editor. *)

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
(* Whether what is shown follows what is written (rio's scroll and
 * noscroll; it does, at first: rio's does not, but with -s). When it
 * does not and the rectangle is full, what is written is below what is
 * shown: one scrolls to read it, and a window holds its program's
 * writes until then (a pager for any program). [set_scrolling t true]
 * shows the end. *)
val scrolling : t -> bool
val set_scrolling : t -> bool -> unit
(* whether the end of the text is shown *)
val at_end : t -> bool
(* The mouse in the text's rectangle: what it means there. A button
 * just pressed in the scroll bar scrolls, as rio's: the left one back,
 * the right one forward, by the lines the mouse is below the bar's
 * top; the middle one to that place among all the lines. The left
 * button in the text selects, from where it goes down to where the
 * mouse is until it comes up: the text selected is shown on a mark.
 * Pressed again at the same place within half a second (a double
 * click, rio's wdoubleclick): just after an opening bracket or quote,
 * what is up to the one that closes it (just before a closing one,
 * back to the one that opens it), on that line; at a line's start or
 * end, the line; else the word there. *)
val mouse : t -> Mouse.state -> unit
(* the middle button's menu (rio's button2menu, in its terminal.c),
 * called when that button has just gone down at a point of [screen]:
 * snarf keeps the text selected (one kept for all the texts), paste
 * gives what is kept, send the same and a newline (if it has none
 * at its end): text for the caller to type in the window (the line
 * being typed is the window's). Its last item, scroll or noscroll, is
 * what the text does not do now: the caller tells the window. *)
type answer = Typed of string | Scroll of bool | Nothing
val menu : t -> Display.image -> Mouse.t -> Point.t -> answer
(* all the text, its lines ended by newlines but the last (a window's text file) *)
val contents : t -> string
(* the text kept (the window system's snarf file reads and writes it) *)
val snarf : string ref
(* whether a point of a text's rectangle is in its scroll bar (for the
 * window system, which keeps the buttons that are not: its menu) *)
val in_bar : Rectangle.t -> Point.t -> bool
(* all of it drawn again (a program drew over it) *)
val redraw : t -> unit
(* the same text in another rectangle, or another image (its window
 * moved, or made another size) *)
val reshape : t -> Display.image -> Rectangle.t -> t
