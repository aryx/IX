(* Layout: a document's blocks put on lines. Each word is given its
 * place, and the lines are broken where the words stop fitting.
 *
 *   Para "Tr copies the standard input to the standard output with
 *         substitution or deletion of selected characters."
 *
 *   width 40, the text's margin 5:
 *
 *        Tr copies the standard input to the
 *        standard output with substitution or
 *        deletion of selected characters.
 *        ^5                                  ^40
 *
 * Lines are filled greedily, as troff fills them: a word goes on the
 * line if it fits, and otherwise it starts the next line; a line, once
 * left, is not looked at again. (TeX's way, which breaks the paragraph
 * as a whole, is for later and would sit beside this one; see
 * docs/plans/done/plan_typesetting.md.) A word too long for a line has
 * the line to itself and goes past the edge.
 *
 * A line may also end inside a word. It may end after a hyphen of the
 * word itself (twenty-|seven, but not a hyphen that is the first
 * letter, as in -c), if one more hyphen would still fit, which is
 * troff's test. It may also end where the text says a word may be cut
 * (U+00AD), with a hyphen added. Nothing is hyphenated by rule, as a
 * terminal's manual never was.
 *
 * Layout sees no font and no terminal. A word's width is given by the
 * caller's [metrics], so that a terminal's writer gives one column for
 * every character and a typesetter's writer gives the widths of Times.
 * Widths and places are in the writer's own unit, a column for a
 * terminal and a thousandth of a point for paper, and they are whole
 * numbers of it. Sums of whole numbers are the same whatever computes
 * them, so a file written from them has the same bytes. The document's
 * lengths, in ens, are turned into that unit here ([en] says how many
 * units an en is). A place is measured from the paper's left.
 *
 * What comes out is rows. A row is a line of words, or room left
 * before the next row (in lines, and maybe less than one: 0.4 between
 * two paragraphs on paper). There are no pages here; the writer cuts
 * the rows into pages.
 *
 * On paper, a line is also made even. When it ends because the next
 * word did not fit, the room left is shared between its spaces, so
 * that the right edge is straight (troff's .ad). This is not done for
 * a paragraph's last line, nor for a line that is not filled.
 *
 * A tagged paragraph is the only block with two things on a line:
 *
 *        -c   Complement string1: replace it      the tag fits in its
 *             with a lexicographically ...        width, so the body
 *                                                 starts on its line
 *        -cds
 *             The three of them.                  it does not fit, so
 *                                                 the body is below
 *)

(* [x] is in the writer's units. *)
type piece = { x : float; style : Doc.style; text : string }

type row =
  (* (an empty one is a blank line among lines that are not filled) *)
  | Line of piece list
  | Skip of float
  (* a footnote's rows, which the writer puts at the foot of the sheet *)
  | Foot of row list
  (* rows that must not be cut by the end of a sheet *)
  | Together of row list
  (* a line drawn across, from one place to another, in a table *)
  | Rule of float * float
  (* a picture, with its left edge at a place *)
  | Drawing of float * Doc.picture
  (* where an anchor is (Doc.Anchor): the sheet of the next line *)
  | Mark of string * bool

(* How a page looks, which is not for the document to say. Its lengths
 * are in the writer's units. *)
type look = {
  (* how many units an en is, and an inch *)
  en : float;
  inch : float;
  (* the length of the line: the document's, put here by [rows] *)
  width : float;
  (* what must be left between a tag and its width for the body to
   * start on the tag's line *)
  tag_room : float;
  (* whether the right edge of the lines is made even *)
  justify : bool;
}

(* a text's width in a style, in the writer's units, as a whole
 * number *)
type metrics = Doc.style -> string -> float

(* (A [Doc.Page] is laid out as its own text. The writer that has
 * sheets puts their numbers in first, with Doc.pages.) *)
val rows : look -> metrics -> Doc.t -> row list

(* a text on one line, starting from a place: its pieces, and where it
 * ends *)
val one_line : metrics -> float -> Doc.inline list -> piece list * float
