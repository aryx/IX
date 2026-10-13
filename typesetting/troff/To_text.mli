(* To_text: a document as a terminal's page -- what nroff gave: every
 * letter one column wide, no font, the lines 65 letters long.
 *
 *      TR(1)                                                       TR(1)
 *
 *      NAME
 *           tr - translate characters
 *
 *      SYNOPSIS
 *           tr [ -cds ] [ string1 [ string2 ] ]
 *
 * The numbers are Plan 9's manual's on a terminal (tmac.an's .if n):
 * the paper's edge 5 columns from the terminal's, the text 5 further,
 * a subsection's heading 3. One page, as long as the document: a
 * terminal has no sheets, and what shows the text scrolls.
 *
 * Fonts are not shown. (nroff could: a letter, a backspace and the
 * same letter again was bold on a printing terminal, an underscore
 * under it italic, and a pager turned those into the screen's own
 * bold. Not done.)
 *)

(* the page's lines, each ended by a newline *)
val page : Doc.t -> string
