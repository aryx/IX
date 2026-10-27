(* What TinyBrowser keeps of a page, its lines, and how words become
 * lines: a flow wraps them at the screen's width, and a table's cells,
 * kept until </table>, are laid out side by side. TinyBrowserPage says
 * which words go where; TinyBrowser draws the lines.
 *
 * A line is a few runs, each a text at a column with a look and a
 * link; so a line costs what its text costs, and drawing one is a
 * string a run:
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
 * the autolayout that HTML 4's specification sketches in an appendix
 * works the same way, each column between its minimum and its maximum
 * width (from memory). Plan 9's mothra shows a table's rows as cells
 * one after the other, not in columns.
 *)

(* The look of a run is a combination of these bits (big: a large
 * heading's, drawn twice the size; under: underlined, <u> and <ins>). *)
val bold : int
val emph : int
val code : int
val big : int
val under : int

(* A run is a piece of text at a column, with a look and the address it
 * links to ("" if it is not a link); or, when [pic] is not -1, a slice
 * of a picture 16 pixels high: the picture's number times 256, plus
 * which slice (-2: the bottom half of a large heading's line). A line
 * is a list of runs, from left to right. A rule is a line drawn across
 * the screen, under a heading or for an <hr>. *)
type run = { col : int; text : string; look : int; link : string; pic : int }
type line = { runs : run list; rule : bool }

(* A flow wraps words into lines of a given width, starting at a left
 * margin. *)
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

(* an empty flow of that width *)
val flow : int -> flow

(* Adds a finished line (after a blank one when the flow wants it). *)
val push : flow -> line -> unit

(* Ends the line being built, if it has anything. *)
val end_line : flow -> unit

(* [word flow text look link space] adds a word, after a space if
 * [space]: on this line if it fits, else on the next one, with the
 * pieces of the same word before it (a link and the comma after it). *)
val word : flow -> string -> int -> string -> bool -> unit

(* [picture_block flow id rows link]: [rows] lines, each a slice of the
 * picture [id], at the left margin. *)
val picture_block : flow -> int -> int -> string -> unit

(* [verbatim flow text look link] adds a text as it is, with no
 * wrapping (<pre>'s). *)
val verbatim : flow -> string -> int -> string -> unit

(* A cell's words, kept until the end of its table: a word (its text,
 * look, link and whether a space was before it), a line's end, or a
 * picture (its number, columns, rows and link). *)
type item =
  | Word of string * int * string * bool
  | Break
  | Pic of int * int * int * string

(* A cell spans [span] columns (a caption: 1000, all of them); a head
 * (<th>, <caption>) is bold. *)
type cell = { mutable items : item list; span : int; head : bool }
type table = {
  mutable rows : cell list list;  (* the rows so far, last row first *)
  mutable row : cell list;
  mutable cell : cell option;
  mutable depth : int;            (* how many tables are open inside it; their
                                   * cells just become text of the current cell *)
  mutable broken : int;           (* a line's end not yet in the cell, put
                                   * there before the next word: 1 a block's,
                                   * 2 an inner table's row's *)
}

(* Lays out a finished table into the flow: each cell is wrapped in its
 * column, and the cells of a row are put side by side. *)
val lay_table : flow -> table -> unit
