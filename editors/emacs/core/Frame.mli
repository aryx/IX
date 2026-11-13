(* A frame is a buffer seen through a rectangle of the screen, from a
 * line on, with the cursor where one types and a status line under
 * it.
 *
 * {b Nothing that is shown is repaired} (efuns' Frame keeps each line
 * of the screen and repairs it as the text changes). The rows are
 * made from the text, from the frame's first line, one byte after the
 * other, and written in a screen of cells; Curses sends what differs
 * from the screen before. The rows are made again when the text, the
 * first line, the size or the colors are not what they were when the
 * rows were last made, and they are kept otherwise (for a key that
 * only moves the point).
 *
 *     the text "ab\n\tc\n", a frame of 3 rows and 40 columns, the point after c
 *
 *         ab
 *                 c_           a tab goes to the next column of 8
 *         -----  f.txt  (Fundamental)  L2 C9 -----
 *
 * A line longer than the frame is folded: there is a \ in its last
 * column, and the rest goes on the next row. A character is UTF-8: a
 * wide one (Chinese, an emoji) takes two columns, and a combining
 * accent takes none and goes over the character before it
 * (Utf8.width). A control character shows as ^A, and a byte that is
 * no character shows as its number, \377. If the point is not in the
 * rows shown, the frame moves so that the point's line is in the
 * middle.
 *
 * This is the editor's redisplay, all of it, in three steps, and the
 * first two are here:
 *
 *     the text's bytes, from the frame's first line
 *        | a character at a time: a tab, ^A, a wide one, a fold;
 *        | its color is the mode's (Ebuffer.colors), reversed or not
 *     rows of pieces: a column, a text, how it is shown
 *        | kept while the text, the first line, the size and the
 *        | colors are the same ([cache])
 *     a screen of cells (Curses.t), with the other frames' rows
 *        | Curses finds the difference with the screen before (in a
 *        | window, Cells does)
 *     the bytes a terminal is sent, the cells a window paints
 *
 * No command calls the redisplay, and no command says what it
 * changed. The redisplay looks at the text and the point after each
 * key, and that is enough for it to scroll (as the paragraph above
 * says, when the point is out of the rows).
 *
 * cs-history:
 * Redisplay was the hard part of an Emacs for as long as the screen
 * was a terminal at the end of a slow line. Sending less was worth
 * any computation. A terminal that could insert or delete a line
 * moved the rest of the screen by itself, so the editor had to find,
 * between the screen shown and the one wanted, the cheapest series
 * of line insertions, deletions and rewritings. James Gosling's
 * Emacs did it by dynamic programming, as an edit distance between
 * two screens ("A Redisplay Algorithm", 1981), in a file known for
 * the skull and crossbones drawn in a comment at its top. Here that
 * work is done by Curses, as a comparison cell by cell, because a
 * terminal of today is a program on the same machine.
 *
 * others:
 * GNU Emacs's redisplay (xdisp.c) is some forty thousand lines. It
 * handles fonts of several widths, pictures, text hidden or shown as
 * something else, two directions of writing, and it takes care never
 * to look at more text than is on the screen. efuns' redisplay is a
 * table of the frame's lines, each line repaired when the text under
 * it changed. In this one, a change makes all the frame's rows again:
 * that is forty rows of a hundred bytes.
 *
 * References: James Gosling, "A Redisplay Algorithm" (ACM SIGPLAN
 * SIGOA Symposium on Text Manipulation, 1981); Craig Finseth, "The
 * Craft of Text Editing" (1991), chapter 7, "Redisplay"; efuns'
 * book, "Trace of a line rendering"; Curses.mli, for the difference. *)

(* {b Colors.} A character is shown as its buffer's mode says from the
 * whole text (Ebuffer.colors: a keyword, a comment), and in reverse
 * where one of the editor's edt_highlights says so (the parenthesis
 * that matches, what a search found). *)

(* makes a frame on a buffer, at the place where the last frame on it
 * was. It has no place on the screen yet (Window.place). *)
val create : Efuns.caps -> Efuns.buffer -> Efuns.frame

(* [change_buffer] puts the frame on another buffer, which then
 * becomes the first of the editor's buffers. [kill] puts the frame on
 * no buffer: the text no longer keeps its points. The buffer left
 * keeps where the frame was. *)
val change_buffer : Efuns.frame -> Efuns.buffer -> unit
val kill : Efuns.frame -> unit

(* [point] gives the point's position, and [goto] moves the point (to
 * the nearest end, for a position out of the text) *)
val point : Efuns.frame -> int
val goto : Efuns.frame -> int -> unit

(*****************************************************************************)
(* {1 Columns} *)
(*****************************************************************************)

(* [next text pos] is the position after the character at pos (its
 * UTF-8 bytes passed), and [prev] is the position of the character
 * before. At an end of the text, they give pos. *)
val next : Text.t -> int -> int
val prev : Text.t -> int -> int

(* the column pos is shown at, as if its line were not folded *)
val column : Text.t -> int -> int

(* [position_of_column text bol col]: in the line that starts at bol,
 * the position shown at col, or the line's end if the line is
 * shorter *)
val position_of_column : Text.t -> int -> int -> int

(*****************************************************************************)
(* {1 The screen} *)
(*****************************************************************************)

(* [recenter frame above] changes the frame's first line so that the
 * point's line is shown with [above] lines before it *)
val recenter : Efuns.frame -> int -> unit

(* [point_shown] says whether the point is in the rows shown;
 * [last_line] gives the start of the last line that starts in them *)
val point_shown : Efuns.frame -> bool
val last_line : Efuns.frame -> int

(* [position_at frame row col] gives the position shown at a cell of
 * the frame (the row and column are the frame's): the character
 * there, or the last one of its row before it. Below the text, it
 * gives the text's end. *)
val position_at : Efuns.frame -> int -> int -> int

(* writes the frame on the screen at its place (after moving the frame
 * first, if the point was not shown), and gives where its cursor is:
 * the row and the column, the screen's *)
val display : Efuns.frame -> Curses.t -> Curses.t * (int * int)

(* [written frame screen] says that the frame's rows are on this
 * screen, as [display] wrote them, with nothing over them. A top
 * window says this of the screen it gives its host. When [cache] is
 * set, a frame's rows are kept, and taken again from that screen,
 * while what they were made of is the same (Frame.ml says what that
 * is, and what it saves). When it is unset, they are made at each
 * key. *)
val written : Efuns.frame -> Curses.t -> unit
val cache : bool ref
