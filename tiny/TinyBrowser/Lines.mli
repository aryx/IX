(* The lines, which are what TinyBrowser keeps of a page, and how words
 * become lines. A flow wraps the words at the screen's width, and the
 * cells of a table, kept until </table>, are laid out side by side.
 * Html decides which words go where; TinyBrowser draws the lines.
 *
 * A line is a few runs, and each run is a text at a column, with a
 * look and maybe a link. So a line costs only what its text costs, and
 * drawing it takes one string per run:
 *
 *     col 0                   col 22   col 24
 *     "OCaml is a dialect of" "ML"     ", with objects"
 *      look 0                  link     look 0
 *                              "./ML"
 *
 * A table is the one place where a line cannot be made at once,
 * because a column must be as wide as its widest cell, which we only
 * know at the end of the table. So the words of each cell are kept
 * (items) until </table>. Then each column gets a width: at least its
 * longest word, its whole text if there is room, and otherwise a share
 * of the remaining room proportional to what it would need. Each cell
 * is then a flow of its column's width, and the rows are laid out side
 * by side.
 *
 * others:
 * The automatic layout that the HTML 4 specification sketches in an
 * appendix works the same way, giving each column a width between its
 * minimum and its maximum (from memory). Plan 9's mothra shows a
 * table's rows as cells one after the other, not in columns.
 *)

(* A look is made of bits to combine; [big] is a heading drawn twice the
 * size. *)
type look = int
val bold : look
val emph : look
val code : look
val big : look
val under : look

(* A big heading's top half is the line above, with the same runs. A
 * rule is drawn across the screen, under a heading or for <hr>. *)
type part =
  | Run_text
  | Run_lower                 (* a big heading's bottom half *)
  | Run_slice of int * int    (* a picture's number, its 16-pixel slice *)
type run = {
  col : int;
  text : string;
  look : look;
  link : string option;
  part : part;
}
type line = { runs : run list; rule : bool }

type flow = {
  width : int;
  mutable left : int;
  mutable made : run list;  (* the line being built, last run first *)
  mutable at : int;         (* the column where the next word goes *)
  mutable out : line list;  (* the finished lines, last line first *)
  mutable nlines : int;     (* how many lines are in out *)
  mutable blank : bool;     (* whether the next line wants a blank line
                             * before it *)
  mutable glue : int;       (* the column where the word being made started *)
  mutable cache : line array;  (* the lines from the top, when there were
                                * [cached] *)
  mutable cached : int;
}

val flow : int -> flow

val push : flow -> line -> unit
val end_line : flow -> unit

(* [word flow text look link space]: a word that does not fit goes to
 * the next line with the pieces of the same word before it (a link and
 * the comma after it). *)
val word : flow -> string -> look -> string option -> bool -> unit

(* [picture_block flow id rows link] *)
val picture_block : flow -> int -> int -> string option -> unit

(* [verbatim] is for <pre>: its lines are not wrapped *)
val verbatim : flow -> string -> int -> string option -> unit

(* A cell's words are kept until the end of its table. A Word's bool
 * says whether there is a space before it. A Pic holds a picture's
 * number, its columns, its rows and its link. *)
type item =
  | Word of string * look * string option * bool
  | Break
  | Pic of int * int * int * string option

(* A cell spans [span] columns (a caption spans 1000, which means all
 * of them). A head cell (<th>, <caption>) is bold. *)
type cell = { mutable items : item list; span : int; head : bool }
type table = {
  mutable rows : cell list list;  (* the rows so far, last row first *)
  mutable row : cell list;
  mutable cell : cell option;
  mutable depth : int;            (* how many tables are open inside it;
                                   * their cells just become text of the
                                   * current cell *)
  mutable broken : int;           (* a line end not yet put in the cell,
                                   * added before the next word: 1 for a
                                   * block's end, 2 for an inner table's
                                   * row end *)
}

val lay_table : flow -> table -> unit
