(* A screen of cells shown as a picture: each cell a character of a
 * font whose characters are all one size, on its background, as the
 * PC's text screen was. What the hosts that are no terminal share (a
 * window of Plan 9's draw device, one of SDL, a picture in a file):
 * a host says how a rectangle is filled and a character drawn (a
 * [surface]), and [show] does what Curses.refresh does for a
 * terminal: from the screen shown and the next one, what changed,
 * painted.
 *
 * The colours are the PC's 16 (the CGA's: Vt's eight, and bold their
 * bright ones: Turbo Pascal's yellow on blue is bold yellow; without
 * bold, yellow is brown). The PC's box characters are not in a font of
 * Latin-1, Plan 9's default one: they are drawn here, lines in a cell.
 * The cursor is the PC's: the cell's last two rows of pixels.
 *
 *     a Tui program's view  -->  Curses.t, a screen of cells
 *                                   |
 *          Curses.refresh           |           Cells.show
 *          bytes for a terminal     |           rectangles and glyphs
 *          (Tty_unix)               |           on a surface:
 *                                               Picture (Window_sdl, a
 *                                               file), the draw device
 *                                               (Window_draw)
 *
 * cs-history:
 * The IBM PC (1981) had no terminal between a program and its
 * screen. In text mode the screen was 80 by 25 cells of the
 * machine's own memory, two bytes a cell: the character's code and
 * an attribute, four bits of foreground colour and four of
 * background (or three and a blinking). A program wrote in that
 * memory and the adapter's character generator drew it, from a ROM
 * of 256 characters whose upper half had the single and double lines
 * that every DOS program framed its windows with. No escape
 * sequence, no baud rate, nothing to optimize: that is the screen
 * Turbo Pascal's IDE was written for, and what [show] gives a Tui
 * program back, a Curses.t standing for the video memory.
 *
 * terminology:
 * Brown. The 16 colours are three bits of red, green and blue and
 * one of intensity; dark yellow by that rule is a dull olive, and
 * IBM's colour monitor halved its green to show brown in its place.
 * Hence yellow is the bright one alone, and a terminal's colour 3,
 * yellow by the standard's name, is brown on a PC. *)

(* What a host with a keyboard and a mouse of its own gives a Tui
 * program: the bytes a terminal sends.
 * [key alt ctrl name]: a key, by Vt.key's name or a character (itself;
 * after Escape with Alt); None: no such key.
 * [click button row col]: the mouse, as xterm reports it (ESC [ < b ;
 * col ; row M, rows and columns from 1): button 0 the left one
 * pressed, 64 and 65 the wheel up and down. A program that does not
 * know them takes them for a key it has not; a host sends them only
 * if asked (its run's mouse). *)
val key : bool -> bool -> string -> string option
val click : int -> int -> int -> string

type rgb = int * int * int

type surface = {
  (* a cell's size in pixels: the font's *)
  w : int;
  h : int;
  (* a rectangle filled: its top left corner, the point past its bottom right one *)
  fill : int * int * int * int -> rgb -> unit;
  (* [glyph x y color c]: the character c (its UTF-8 bytes) drawn in the cell whose corner is (x, y) *)
  glyph : int -> int -> rgb -> string -> unit;
}

(* a cell's colours: its character's, its background's *)
val colors : Vt.attrs -> rgb * rgb

(* a box character's lines in a cell of w by h, as rectangles from the
 * cell's corner; None: a character of the font *)
val box : string -> int -> int -> (int * int * int * int) list option

(* cells that changed, side by side on a row and of the same colours *)
type run = { row : int; col : int; glyphs : string list; fg : rgb; bg : rgb }

(* what differs from [before] (None, or a screen of another size: all
 * of it), the cells under the cursor's old and new places with it *)
val runs : Curses.t option -> Curses.t -> run list

(* [show surface before next]: the runs painted, then the cursor *)
val show : surface -> Curses.t option -> Curses.t -> unit
