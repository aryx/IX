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
 * beside this one: docs/plans/plan_typesetting.md.) A word too long
 * for a line has the line to itself and goes past the edge.
 *
 * A line may also end inside a word, after a hyphen of its own
 * (twenty-|seven; not the first letter's, -c), if a hyphen more would
 * still fit, which is troff's test; and where the text says a word
 * may be cut (U+00AD), with a hyphen added. Nothing is hyphenated by
 * rule: a terminal's manual never was.
 *
 * It sees no font and no terminal: a word's width is the caller's
 * [metrics], in ens, so that a terminal's writer gives one for every
 * character and a typesetter's will give Times's. A place is in ens
 * from the paper's left; a line is one line of the paper, an empty
 * list a blank one.
 *
 * A tagged paragraph, the only block with two things on a line:
 *
 *        -c   Complement string1: replace it      the tag fits in its
 *             with a lexicographically ...        width: the body starts
 *                                                 on its line
 *        -cds
 *             The three of them.                  it does not: below
 *)

type piece = { x : float; style : Doc.style; text : string }

type line = piece list

(* how a page looks, which is not the document's to say *)
type look = {
  (* the line's length *)
  width : float;
  (* where the text is, from the left: a section's heading is at 0, a
   * subsection's at [sub] *)
  margin : float;
  sub : float;
}

(* a text's width in a style, in ens *)
type metrics = Doc.style -> string -> float

val lines : look -> metrics -> Doc.block list -> line list
