(* TinyOffice's file: a document's pages as text in mini-troff's format
 * (plan_typesetting.md), which is Markdown lines plus
 * \name[options]{text} for what Markdown lacks. Each object is a \box
 * at its place (x, y, width, height); its content is the lines up to
 * one that holds a } alone. A line \newpage separates two pages (as in
 * LaTeX):
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
 * The content tells the object's kind:
 * - a table is a sheet: its header is the columns' letters, then each
 *   line is a row, holding what was typed in each cell; the sheet's
 *   name comes after the box's numbers;
 * - a fence ```drawing, ```paint or ```chart is that kind of object,
 *   with its lines kept as they are;
 * - anything else is text.
 * A text's styles are Markdown's: **bold**, *italic*, a line starting
 * with "# " for large, plus \u{} for underlined and \large{} for large
 * inside a line. So emacs can edit a page like any text (there is no
 * byte count to keep right), tiny-troff can print it, and a Markdown
 * file, which has no \box, opens as a single text box.
 *
 * design:
 * A document's file is a text that other programs can read, not the
 * program's values marshalled (as in mini-office's Saved): the format
 * outlives the program.
 *)

(* [parse width height text]. The page size is used for the single box
 * of a Markdown file. *)
val parse : int -> int -> string -> Model.obj list

(* The boxes of each page, with a line \newpage between two pages and an
 * empty line between two boxes. *)
val text : Model.office -> string

(* how many pages a document's file has: one, plus one per \newpage *)
val pages_in : string -> int

(* recounts the pages after a change, at least as many as objects need *)
val fit_pages : Model.office -> unit
