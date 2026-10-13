(* To_pdf: a document as the pages of a PDF file -- what troff gave a
 * typesetter: letters of their own widths, the lines' right edge
 * even, sheets of paper.
 *
 *   Doc.t --Layout.rows--> lines of words, each at its place, by the
 *   widths of Times --> cut into pages, a header and a number on
 *   each --Pdf_write--> the file's bytes
 *
 * The paper is American (8.5 by 11 inches), the text 10 points on 12
 * in lines of 6.5 inches, an inch from the left: the numbers of Plan
 * 9's manual. Four fonts, as troff mounted four: Times for the text,
 * its italic and its bold, Courier for what is typed. The file names
 * them and carries none: a reader has them, or others of the same
 * widths (Standard_widths.mli says how that came to be). So what is
 * computed here with Adobe's widths breaks its lines where a printer
 * will, and mini-page, which draws its own stroke letters at those
 * widths, shows the same lines.
 *
 * Characters are the 217 of the fonts' encoding (Windows'). A minus
 * is its dash in Times, the back quote and the quote its two quotation
 * marks, as troff's; an arrow, which those fonts have not, is written
 * with a hyphen and a sign. What has no way of being written is a
 * question mark, and is in the list this gives back: said, not lost.
 *
 * Pages are cut where the paper ends, wherever that is in the text:
 * no line is kept with the next yet (a heading may be a page's last
 * line), and a space that would start a page is dropped.
 *
 * Not written: a font carried in the file (for the characters these
 * have not), links, a table of contents, anything but black. *)

(* the file's bytes, each character that could not be written, and
 * how many lines go past the paper's right edge (a line that is not
 * filled is as long as it was written: troff lets it run off the
 * sheet without a word; this counts them) *)
val file : Doc.t -> string * string list * int

(* a text as it is written in a font: the characters put for others *)
val shown : Doc.font -> string -> string

(* a text's width in ens of the text's size, by the fonts' own widths:
 * what a reader needs to measure with (Roff.set_measure) *)
val measure : Doc.inline list -> float
