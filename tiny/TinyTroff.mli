(* tiny-troff: a document of mini-troff's format (plan_typesetting.md),
 * a page of tiny-office's or a Markdown file, printed as text or as
 * HTML. The office edits a page as it is shown; emacs edits it as it
 * is written (Markdown's lines, \box[x y w h]{...} around each part);
 * tiny-troff publishes it (step 6 of plan_tiny_office.md).
 *
 *     page.ixd ──▶ TinyOffice's parse ──▶ the parts, in reading order
 *                                          (top, then left)
 *                                              │
 *                          text ◀──────────────┴──────────────▶ HTML
 *
 * It reads a page with the office's own functions (TinyOffice.mli's
 * last part), so the format is written down once. A part is printed as
 * its kind asks:
 *
 *     part      as text                          as HTML
 *     text      each line filled to the width,   a line a <p>, a large
 *               a large line underlined by =     one an <h1>; <b> <i>
 *                                                <u>, large words big
 *     sheet     its values in columns, a number  a <table> of its
 *               at its column's right            values
 *     drawing   characters, one for 8 by 8       SVG: rectangles, lines
 *               pixels: + - | for a box, its     and their heads, texts
 *               label in it, > < v ^ an arrow's
 *               head
 *     paint     its rows, white a space          SVG: a rectangle a run
 *                                                of a colour, 4 by 4 a
 *                                                pixel
 *     chart     a line a bar: its label, #s for  SVG: the bars as the
 *               its share of the largest, its    office draws them
 *               value
 *
 * As text, the parts come one after the other, an empty line between
 * two. As HTML, each is at its place on the page (a box positioned in a
 * page of the parts' size), as the office shows it.
 *
 * cs-history:
 * troff (Joe Ossanna, 1973) made the documents of Unix from a text
 * with requests, for the screen (nroff) and for the phototypesetter;
 * its preprocessors (tbl, eqn, pic) turned tables, equations and
 * drawings into more requests. Here the parts are the tables and the
 * drawings, and the page they are on is both what the office shows and
 * the text troff reads: Bravo's and troff's ways to one document.
 *
 * Left out: PDF (a writer of its own, some 100 lines), pages (a long
 * document is one page), the paint as a picture (a BMP: SVG's
 * rectangles instead), and the office's own colours and fonts in the
 * HTML (the browser's monospace). *)

(* [to_text width doc]: the document as text, its lines filled to width *)
val to_text : int -> string -> string

(* [to_html title doc]: the document as a web page *)
val to_html : string -> string -> string
