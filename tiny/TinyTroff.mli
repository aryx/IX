(* tiny-troff prints a document in mini-troff's format
 * (plan_typesetting.md), either a tiny-office page or a Markdown file,
 * as text, HTML or PDF. The office edits a page as it is shown; emacs
 * edits it as it is written (Markdown lines, with \box[x y w h]{...}
 * around each part); tiny-troff publishes it (step 6 of
 * plan_tiny_office.md).
 *
 *     page.ixd ──▶ File.parse ──▶ the parts, in reading order
 *                                              (top, then left)
 *                                                  │
 *                              text ◀──────────────┴──────────────▶ HTML
 *
 * It reads a page with the office's own functions (the parts in
 * TinyOffice/: File, Text, Sheet...), so the format is defined in only
 * one place. Each part is printed according to its kind:
 *
 *     part      as text                          as HTML
 *     text      each line filled to the width;   a <p> per line, an
 *               a large line underlined by =     <h1> for a large one;
 *                                                <b> <i> <u>, and big
 *                                                for large words
 *     sheet     its values in columns, numbers   a <table> of its
 *               aligned right                    values
 *     drawing   one character per 8x8 pixels:    SVG: rectangles, lines
 *               + - | for a box with its label   with their heads, texts
 *               inside, > < v ^ for an arrow's
 *               head
 *     paint     its rows, a space for white      SVG: one rectangle per
 *                                                run of a colour, 4x4
 *                                                per pixel
 *     chart     one line per bar: its label, #s  SVG: the bars as the
 *               scaled to the largest value,     office draws them
 *               and its value
 *
 * As text, the parts come one after the other, separated by an empty
 * line, with a form feed between two pages (as nroff does). As HTML,
 * each part is at its place on its page (a positioned box inside a
 * block as large as the page's parts), and the pages come one under
 * the other, as the office shows them. As PDF, each page is a PDF
 * page, all of them the size of the largest.
 *
 * twin:
 * mini-troff (typesetting/) reads input written for troff (the macros
 * of manual pages and papers, tbl, pic), LaTeX, and the same Markdown
 * lines, into one document type (Doc), laid out for a terminal or as a
 * PDF in Times. Compared with it, tiny-troff differs in three ways:
 * - a part stays at its place on its page, where mini-troff fills a
 *   flow of paragraphs;
 * - it writes HTML, which mini-troff does not;
 * - its PDF is in Courier, where every character has the same width,
 *   so no font metrics are needed.
 * Plan 9's troff (principia's typesetting/troff/) is the original of
 * both. Plan 9 makes HTML with separate programs: troff2html from
 * troff's output, and htmlroff from -ms input (principia's
 * typesetting/).
 *
 * dropped:
 * A text cannot flow onto the next page. A paint is not a real image (a
 * BMP); we use SVG rectangles instead. The HTML does not have the
 * office's colours and fonts; it uses the browser's monospace font.
 *
 * twist:
 * There is only one format, the office's, read by the office's own
 * functions. mini-troff reads troff's macros, LaTeX and Markdown into a
 * document type of its own; here there is no such type, no roff and no
 * LaTeX, and the format is defined once, for the office, emacs and
 * troff alike.
 *
 * cs-history:
 * troff (Joe Ossanna, 1973) produced the documents of Unix from text
 * with requests in it, for the terminal (nroff) and for the
 * phototypesetter. Its preprocessors (tbl, eqn, pic) turned tables,
 * equations and drawings into more requests. Here the parts play the
 * role of the tables and drawings, and the page they are on is both
 * what the office shows and the text that troff reads: Bravo's way and
 * troff's way lead to the same document. *)

(* [to_text width doc] fills the lines to width. *)
val to_text : int -> string -> string

val to_html : string -> string -> string

(* One PDF page per page, all the size of the largest, one point per
 * pixel. Text is in Courier at 13.33 points, so that a character is 8
 * points wide as in the office's 8x16 font, and is laid out as the
 * office does. Sheets are drawn as grids, drawings as lines, and paints
 * and charts as rectangles. Because it uses standard fonts and no
 * compression, the PDF writer takes only about 120 lines. *)
val to_pdf : string -> string

(* "troff [-h | -p] file" prints the file as text (72 columns), as HTML
 * (-h) or as PDF (-p). *)
val main : < Cap.open_in; Cap.stdout; Cap.stderr; .. > -> string array -> Exit.t
