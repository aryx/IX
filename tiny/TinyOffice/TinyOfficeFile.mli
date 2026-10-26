(* TinyOffice's file: a document's pages as text in mini-troff's format
 * (plan_typesetting.md), Markdown's lines, and \name[options]{text} for
 * what Markdown has not. Each object is a \box at its place (x, y,
 * width, height), its content the lines up to one that is a } alone; a
 * line \newpage between two pages (LaTeX's):
 *
 *     \box[20 40 200 84]{
 *     # Tiny office
 *
 *     A page of **boxes**, *styled*, \u{underlined}.
 *     }
 *
 *     \box[300 40 282 114 budget]{
 *     | a     | b      |
 *     |-------|--------|
 *     | Rent  | 500    |
 *     | Total | =b1+b2 |
 *     }
 *
 * The kind is in the content: a table is a sheet (its header the
 * columns' letters, then a row a line, what was typed in each cell;
 * its name after its box's numbers), a fence ```drawing, ```paint or
 * ```chart is that (its lines as they are), the rest text. A text's
 * styles are Markdown's, **bold**, *italic*, a line "# " large, and
 * \u{} underlined, \large{} large in a line. So emacs edits a page as
 * any text (no count of bytes to keep right), tiny-troff prints it,
 * and a Markdown file, with no \box, is opened as one text box.
 *
 * design:
 * a document's file is a text that other programs read, not the
 * program's values marshalled (mini-office's Saved): the format
 * outlives the program.
 *)

(* [parse width height text]: the objects of a file's text (a page of
 * that width and height, for a Markdown file's one box) *)
val parse : int -> int -> string -> TinyOfficeModel.obj list

(* the file of a document: each page's boxes, a line \newpage between
 * two pages, an empty line between two boxes *)
val text : TinyOfficeModel.office -> string

(* how many pages a document's file has: one, and one more a \newpage *)
val pages_in : string -> int

(* the pages counted again, after a change: as many as its objects are
 * on, at least *)
val fit_pages : TinyOfficeModel.office -> unit
