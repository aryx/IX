(* mini-office's Export: the document as a PDF file, a page of the
 * file for each page of the document (a slide for each of a
 * presentation's), a unit of the page a point.
 *
 * What is written is what the view draws, less the caret and the
 * selection: every part draws itself as Playground shapes, and those
 * are written as paths (Shape_render_pdf), not as a picture of the
 * screen. The letters are their strokes: the words are not text yet
 * (docs/plans/plan_pdf.md, stage E).
 *
 * The way of a page to the file, each step another module's:
 *
 *   Office_view.page_shapes ~chrome:false    the document's shapes
 *   Shape_render_pdf                         each shape a path, its
 *                                            operators in a content
 *   Pdf_write                                the content a form, drawn
 *                                            once on each page, moved;
 *                                            the pages, the file
 *   File_menu.export                         the bytes written
 *
 * A document's pages are one column for the view, so the column is
 * written once and each page of the file shows its own stretch of
 * it, the paper cutting the rest (the picture is in the .ml). The
 * file can be read back here: mini-page (Pageview) shows it, by
 * Pdf_render, and the tests compare what comes back.
 *
 * cs-history:
 * One drawing for the screen and for the paper is the Macintosh's
 * (1984): a program printed by drawing its page again with the same
 * QuickDraw calls, into a port that was the printer's, where a
 * program before it had one code to show a page and another to
 * print it. PDF (Adobe, 1993) is the same idea made a file:
 * the drawing operators of a page, kept, for any screen and any
 * printer later; Export to PDF is printing to a file.
 *
 * modern:
 * A PDF's words should be text: a string and a font, so that they
 * can be searched, copied and read aloud, and are small. That takes
 * a font in the file, or one of the fourteen every reader has, and
 * then the widths used here to break the lines must be that font's
 * and not Hershey's. *)

val pdf : Office_model.model -> string
