(* A frame: a buffer seen through a rectangle of the screen, from a
 * line on, with the cursor where one types and a status line under.
 *
 * {b Nothing is kept of what is shown} (efuns' Frame keeps each line
 * of the screen and repairs it as the text changes): at each key the
 * rows are made again from the text, from the frame's first line, a
 * byte after the other, and written in a screen of cells; Curses
 * sends what differs from the screen before.
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
 * point's line in the middle. *)

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

(* the frame written on the screen at its place (moved first, if the
 * point was not shown), and where its cursor is: the row and the
 * column, the screen's *)
val display : Efuns.frame -> Curses.t -> Curses.t * (int * int)
