(* mini-office's Export: the document as a PDF file, a page of the
 * file for each page of the document (a slide for each of a
 * presentation's), a unit of the page a point.
 *
 * What is written is what the view draws, less the caret and the
 * selection: every part draws itself as Playground shapes, and those
 * are written as paths (Shape_render_pdf), not as a picture of the
 * screen. The letters are their strokes: the words are not text yet
 * (docs/plans/plan_pdf.md, stage E). *)

val pdf : Office_model.model -> string
