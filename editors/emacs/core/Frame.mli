(* A frame: a buffer seen through a rectangle of the screen, from a
 * line on, with the cursor where one types and a status line under.
 *
 * {b Nothing is repaired of what is shown} (efuns' Frame keeps each
 * line of the screen and repairs it as the text changes): the rows are
 * made from the text, from the frame's first line, a byte after the
 * other, and written in a screen of cells; Curses sends what differs
 * from the screen before. They are made again when the text, the first
 * line, the size or the colors are others than when they were last
 * made, and kept otherwise (a key that only moves the point).
 *
 *     the text "ab\n\tc\n", a frame 3 rows by 12 columns, the point after c
 *
 *         ab
 *                 c_           a tab goes to the next column of 8
 *         ----  f.txt  (Fundamental)  L2 C9 ---
 *
 * A line longer than the frame is folded: a \ in its last column, and
 * the rest on the next row. A character is UTF-8's: a wide one (Chinese,
 * an emoji) is two columns, a combining accent none, over the character
 * before it (Utf8.width). A control character shows as ^A, a byte that
 * is no character as its number, \377. If the point is not in the rows shown, the frame moves: the
 * point's line in the middle.
 *
 * This is the editor's redisplay, all of it, in three steps of which
 * the first two are here:
 *
 *     the text's bytes, from the frame's first line
 *        | a character at a time: a tab, ^A, a wide one, a fold;
 *        | its color the mode's (Ebuffer.colors), reversed or not
 *     rows of pieces: a column, a text, how it is shown
 *        | kept while the text, the first line, the size and the
 *        | colors are the same ([cache])
 *     a screen of cells (Curses.t), with the other frames' rows
 *        | Curses' difference with the screen before (in a window:
 *        | Cells')
 *     the bytes a terminal is sent, the cells a window paints
 *
 * No command calls it and no command says what it changed: it looks
 * at the text and the point after each key, and that is enough for
 * it to scroll (the paragraph above: the point out of the rows).
 *
 * cs-history:
 * Redisplay was the hard part of an Emacs for as long as the screen
 * was a terminal at the end of a slow line. Sending less was worth
 * any computation: a terminal that could insert or delete a line
 * moved the rest of the screen by itself, so the editor had to find,
 * between the screen shown and the one wanted, the cheapest series
 * of line insertions, deletions and rewritings. James Gosling's
 * Emacs did it by dynamic programming, as an edit distance between
 * two screens ("A Redisplay Algorithm", 1981), in a file known for
 * the skull and crossbones drawn in a comment at its top. Here that
 * work is Curses' and is a comparison cell by cell: a terminal of
 * today is a program on the same machine.
 *
 * others:
 * GNU Emacs's redisplay (xdisp.c) is some forty thousand lines:
 * fonts of several widths, pictures, text hidden or shown as another,
 * two directions of writing, and the care never to look at more text
 * than is on the screen. efuns' is a table of the frame's lines,
 * each repaired when the text under it changed. In this one a
 * change makes the frame's rows again, all of them: forty rows of
 * a hundred bytes.
 *
 * References: James Gosling, "A Redisplay Algorithm" (ACM SIGPLAN
 * SIGOA Symposium on Text Manipulation, 1981); Craig Finseth, "The
 * Craft of Text Editing" (1991), chapter 7, "Redisplay"; efuns'
 * book, "Trace of a line rendering"; Curses.mli, for the difference. *)

(* {b Colors.} A character is shown as its buffer's mode says of the
 * whole text (Ebuffer.colors: a keyword, a comment), and in reverse
 * where one of the editor's edt_highlights says (the parenthesis that
 * matches, what a search found). *)

(* a frame on a buffer, where the last frame on it was; no place yet
 * (Window.place) *)
val create : Efuns.caps -> Efuns.buffer -> Efuns.frame

(* the frame on another buffer (which is then the first of the
 * editor's); and no longer on any: its points are the text's no more.
 * The buffer left keeps where the frame was. *)
val change_buffer : Efuns.frame -> Efuns.buffer -> unit
val kill : Efuns.frame -> unit

(* the point's position, and the point moved (to the nearest end, for
 * a position out of the text) *)
val point : Efuns.frame -> int
val goto : Efuns.frame -> int -> unit

(*****************************************************************************)
(* {1 Columns} *)
(*****************************************************************************)

(* [next text pos]: the position after the character at pos (its
 * bytes of UTF-8 passed), and [prev]: of the character before; pos
 * at an end of the text *)
val next : Text.t -> int -> int
val prev : Text.t -> int -> int

(* the column pos is shown at, its line not folded *)
val column : Text.t -> int -> int

(* [position_of_column text bol col]: in the line that starts at bol,
 * the position shown at col, or the line's end if it is shorter *)
val position_of_column : Text.t -> int -> int -> int

(*****************************************************************************)
(* {1 The screen} *)
(*****************************************************************************)

(* the frame's first line changed for the point's line to be shown
 * with [above] lines before it *)
val recenter : Efuns.frame -> int -> unit

(* whether the point is in the rows shown; and the start of the last
 * line that starts in them *)
val point_shown : Efuns.frame -> bool
val last_line : Efuns.frame -> int

(* [position_at frame row col]: the position shown at a cell of the
 * frame (its row and column, the frame's): the character there, or
 * the last of its row before it; the text's end below the text *)
val position_at : Efuns.frame -> int -> int -> int

(* the frame written on the screen at its place (moved first, if the
 * point was not shown), and where its cursor is: the row and the
 * column, the screen's *)
val display : Efuns.frame -> Curses.t -> Curses.t * (int * int)

(* [written frame screen]: the screen is the one the frame's rows are
 * on, as [display] wrote them and nothing over them: what a top window
 * says of the screen it gives its host. And [cache]: a frame's rows
 * are kept, and taken again from that screen, while what they were
 * made of is the same (Frame.ml says of what, and what it saves);
 * unset, they are made at each key *)
val written : Efuns.frame -> Curses.t -> unit
val cache : bool ref
