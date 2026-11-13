(* A window's text (this is how Plan 9's rio shows a window's
 * /dev/cons: its terminal.c; xix's Terminal). The text is lines of
 * characters in a rectangle of an image, in one font whose characters
 * all have the same width. What is written is added at the end, and
 * the lines move up when the rectangle is full. The lines that went
 * off the top are kept (1,000 of them): one scrolls back to them, and a
 * bar on the left shows where what is seen is among them all (rio's
 * scroll bar). The mouse selects text.
 *
 * plan9-is-cleaner:
 * No terminal is emulated. On Unix a window for text is a program
 * that imitates a DEC VT100: what is written to it is text mixed
 * with escape sequences (move the cursor there, clear to the end of
 * the line, use this colour). Programs find those sequences in a
 * database of terminals (termcap, terminfo) and use them through a
 * library (curses), and the kernel has a line discipline between the
 * two. A window here understands a newline and a tab ([put]): text
 * goes at the end, and it stays, so one scrolls back, selects it and
 * sends it again. A program that wants the whole rectangle does not
 * address a cursor: it opens the mouse and draws (Virtual_mouse,
 * Dev_wm), as the editors do. So there is no vi in a Plan 9 window,
 * and no need of clear, reset or stty.
 *
 * In ours, text is added at the end only (Rio says why); rio's text
 * can be edited anywhere, as a file in an editor. *)

type t

val make : Display.image -> Rectangle.t -> Font.t -> t
(* adds text: a newline ends a line, and a tab goes to the next column
 * that is a multiple of 8 *)
val put : t -> string -> unit
(* takes back the last character of the last line (what a backspace
 * does) *)
val erase : t -> unit
(* [scroll t n] moves what is shown by n lines: up (back in what was
 * written) when n is positive, down when it is negative. [half t] is
 * half the lines the rectangle shows (the arrow keys' step, as in
 * rio). *)
val scroll : t -> int -> unit
val half : t -> int
(* Whether what is shown follows what is written (rio's scroll and
 * noscroll). It does at first; rio's does not, unless rio is started
 * with -s. When it does not and the rectangle is full, what is
 * written goes below what is shown. One scrolls to read it, and a
 * window holds its program's writes until then, which makes a pager
 * for any program. [set_scrolling t true] shows the end. *)
val scrolling : t -> bool
val set_scrolling : t -> bool -> unit
(* whether the end of the text is shown *)
val at_end : t -> bool
(* Handles the mouse in the text's rectangle. A button just pressed in
 * the scroll bar scrolls, as in rio: the left one scrolls back and the
 * right one forward, by as many lines as the mouse is below the bar's
 * top, and the middle one scrolls to that place among all the lines.
 * The left button in the text selects, from where it goes down to
 * where the mouse is when it comes up; the selected text is shown on a
 * mark. When the left button is pressed again at the same place
 * within half a second (a double click, rio's wdoubleclick), it
 * selects:
 * - just after an opening bracket or quote, the text up to the one
 *   that closes it on that line (and just before a closing one, the
 *   text back to the one that opens it);
 * - at a line's start or end, the line;
 * - elsewhere, the word there. *)
val mouse : t -> Mouse.state -> unit
(* the middle button's menu (rio's button2menu, in its terminal.c),
 * called when that button has just gone down at a point of [screen]:
 * - snarf keeps the selected text (one text is kept for all the
 *   texts);
 * - paste gives what is kept, and send gives the same with a newline
 *   (if it has none at its end). That is text for the caller to type
 *   in the window (the line being typed belongs to the window).
 * - The last item, scroll or noscroll, is what the text does not do
 *   now; the caller tells the window. *)
type answer = Typed of string | Scroll of bool | Nothing
val menu : t -> Display.image -> Mouse.t -> Point.t -> answer
(* all the text, each line ended by a newline except the last (a
 * window's text file) *)
val contents : t -> string
(* the text kept (the window system's snarf file reads and writes it) *)
val snarf : string ref
(* whether a point of a text's rectangle is in its scroll bar (for the
 * window system, which keeps the presses elsewhere for its menu) *)
val in_bar : Rectangle.t -> Point.t -> bool
(* draws all of it again (when a program drew over it) *)
val redraw : t -> unit
(* the same text in another rectangle, or in another image (when its
 * window was moved, or made another size) *)
val reshape : t -> Display.image -> Rectangle.t -> t
