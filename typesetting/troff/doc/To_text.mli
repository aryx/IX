(* To_text: a document as a terminal's page. This is what nroff gave:
 * every letter is one column wide, there are no fonts, and the lines
 * are 65 letters long.
 *
 *      TR(1)                                                       TR(1)
 *
 *      NAME
 *           tr - translate characters
 *
 *      SYNOPSIS
 *           tr [ -cds ] [ string1 [ string2 ] ]
 *
 * The numbers are those of Plan 9's manual on a terminal (tmac.an's
 * .if n): the paper's edge is 5 columns from the terminal's, the text
 * is 5 further, and a subsection's heading is 3 further. There is one
 * page, as long as the document, because a terminal has no sheets and
 * what shows the text scrolls.
 *
 * Fonts are not shown. (nroff could show them: a letter, a backspace
 * and the same letter again was bold on a printing terminal, and an
 * underscore under it was italic; a pager turned those into the
 * screen's own bold. This is not done here.)
 *)

(* the page's lines, each one ended by a newline *)
val page : Doc.t -> string
