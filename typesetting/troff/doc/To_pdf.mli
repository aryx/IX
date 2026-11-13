(* To_pdf: a document as the pages of a PDF file. This is what troff
 * gave a typesetter: letters of their own widths, lines with an even
 * right edge, and sheets of paper.
 *
 *   Doc.t --Layout.rows--> lines of words, each at its place, by the
 *   widths of Times --> cut into pages, a header and a number on
 *   each --Pdf_write--> the file's bytes
 *
 * The paper is American (8.5 by 11 inches), and the text is 10 points
 * on 12, in lines of 6.5 inches, an inch from the left: these are the
 * numbers of Plan 9's manual. There are four fonts, as troff mounted
 * four: Times for the text, its italic and its bold, and Courier for
 * what is typed. The file names the fonts but carries none of them: a
 * reader has them, or others of the same widths (Standard_widths.mli
 * says how that came to be). So what is computed here with Adobe's
 * widths breaks its lines where a printer will, and mini-page, which
 * draws its own stroke letters at those widths, shows the same lines.
 *
 * The characters are the 217 of the fonts' encoding (Windows'). A
 * minus is written as Times's dash, and the back quote and the quote
 * as its two quotation marks, as troff does. An arrow, which those
 * fonts do not have, is written with a hyphen and a sign. A character
 * that cannot be written at all becomes a question mark, and it is in
 * the list that [file] gives back, so it is reported and not lost.
 *
 * Pages are cut where the paper ends, wherever that is in the text. A
 * block kept together (a Doc.Keep, a table) goes to the next sheet
 * when it does not fit, but a heading is not kept with the line after
 * it (it may be the last line of a page), and a space that would start
 * a page is dropped.
 *
 * A sheet's number written in the text (Doc.Page: a table of contents,
 * a \pageref, a chunk's 12b) is known only once the sheets are cut,
 * and writing it may push a line onto the next sheet. So the sheets
 * are cut twice: they are counted, the numbers are put in, and the
 * document is written. If the numbers have moved, it is counted again
 * until they stay, and then written. This is the rerun that LaTeX asks
 * of its user, done here.
 *
 *   counted (empty)  --numbers-->  written  --same numbers?-->  done
 *
 * Not written: a font carried in the file (for the characters these
 * fonts do not have), links, the outline that a viewer shows beside
 * the pages, and any color but black. *)

(* the file's bytes, each character that could not be written, and how
 * many lines go past the paper's right edge. (A line that is not
 * filled is as long as it was written. troff lets it run off the sheet
 * without a word; this counts them.) *)
val file : Doc.t -> string * string list * int

(* a text as it is written in a font, with the characters that stand
 * for others put in *)
val shown : Doc.font -> string -> string

(* a text's width in ens of the text's size, by the fonts' own widths.
 * A reader needs it to measure with (Roff.set_measure). *)
val measure : Doc.inline list -> float
