(* Layout: a document's blocks put on lines -- each word given its
 * place, the lines broken where the words stop fitting.
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
 * Lines are filled greedily, as troff's: a word goes on the line if it
 * fits, else it starts the next, and a line once left is not looked at
 * again. (TeX's way, the paragraph broken as a whole, is for later and
 * beside this one: docs/plans/done/plan_typesetting.md.) A word too long
 * for a line has the line to itself and goes past the edge.
 *
 * A line may also end inside a word, after a hyphen of its own
 * (twenty-|seven; not the first letter's, -c), if a hyphen more would
 * still fit, which is troff's test; and where the text says a word
 * may be cut (U+00AD), with a hyphen added. Nothing is hyphenated by
 * rule: a terminal's manual never was.
 *
 * It sees no font and no terminal: a word's width is the caller's
 * [metrics], so that a terminal's writer gives one for every
 * character and a typesetter's gives Times's. Widths and places are in
 * the writer's own unit, a column for a terminal, a thousandth of a
 * point for paper, and are whole numbers of it: sums of whole numbers
 * are the same whatever computes them, and a file written from them
 * the same bytes. The document's lengths, in ens, are turned into
 * that unit here ([en] says how many an en is). A place is from the
 * paper's left. What comes out is rows: a line of words, or room
 * left before the next (in lines, and maybe less than one: 0.4
 * between two paragraphs on paper). There are no pages here: the
 * writer cuts the rows into them.
 *
 * On paper a line is also made even: when it ends because the next
 * word did not fit, what room is left is shared between its spaces,
 * and the right edge is straight (troff's .ad; not a paragraph's last
 * line, nor a line that is not filled).
 *
 * A tagged paragraph, the only block with two things on a line:
 *
 *        -c   Complement string1: replace it      the tag fits in its
 *             with a lexicographically ...        width: the body starts
 *                                                 on its line
 *        -cds
 *             The three of them.                  it does not: below
 *)

(* [x]: in the writer's units *)
type piece = { x : float; style : Doc.style; text : string }

type row =
  (* (an empty one: a blank line of lines not filled) *)
  | Line of piece list
  | Skip of float
  (* a footnote's rows: the writer's to put at the sheet's foot *)
  | Foot of row list
  (* rows not to be cut by a sheet's end *)
  | Together of row list
  (* a line drawn across, from a place to another: a table's *)
  | Rule of float * float
  (* a picture, its left edge at a place *)
  | Drawing of float * Doc.picture
  (* where an anchor is (Doc.Anchor): the sheet of the next line *)
  | Mark of string * bool

(* how a page looks, which is not the document's to say; its lengths
 * in the writer's units *)
type look = {
  (* how many units an en is, and an inch *)
  en : float;
  inch : float;
  (* the line's length: the document's, put here by [rows] *)
  width : float;
  (* what must be left between a tag and its width for the body to
   * start on the tag's line *)
  tag_room : float;
  (* the lines' right edge made even *)
  justify : bool;
}

(* a text's width in a style, in the writer's units: a whole number *)
type metrics = Doc.style -> string -> float

(* (a [Doc.Page] is its own text: the writer that has sheets puts
 * their numbers in first, Doc.pages) *)
val rows : look -> metrics -> Doc.t -> row list

(* a text on one line, from a place: its pieces, and where it ends *)
val one_line : metrics -> float -> Doc.inline list -> piece list * float
