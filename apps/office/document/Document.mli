(* mini-office's document: one record, whatever its kind, that holds
 * its parts; and the same record as it is written on the disk.
 *
 *   doc = Component.part doc_
 *     kind      a document, a spreadsheet, a presentation, a picture, a drawing
 *     body      what it is before anything floats on it: its texts (one a
 *               slide), or a part of its own kind (a sheet, a picture...)
 *     objects   the parts that float on it, each placed: where, how
 *               large, on which slide, tied to which paragraph, how the
 *               text goes round it, the sheet a chart is made from
 *     header, footer, ...
 *
 * A part is a record of functions (Component.part): it cannot be
 * written by Marshal. So the document saved is the same record with
 * each part replaced by its kind and the text it saves,
 *
 *   saved = (string * string) doc_
 *
 * which is data: Saved (Marshal behind the line "TinyOffice 1") writes
 * it, File_menu puts it in the platforms' Store, and [of_saved] reads
 * each part back by its kind (the registry: Part_text, Part_sheet,
 * Part_picture, Part_drawing, Part_chart, and ix's Part_image; a kind
 * no one knows is kept whole, a placeholder). One type of file for the
 * five kinds.
 *
 * A letter with a budget on it and a chart of the budget, as a value
 * and as it is saved:
 *
 *   { kind = Document;
 *     body = Texts [ the letter ];             a Rich: data already
 *     objects = [
 *       { id = 1; part = a sheet;  x; y; w; h; link = None; ... };
 *       { id = 2; part = a chart;  ...  link = Some (Sheet_object 1) } ] }
 *
 *   saved:   part = ("sheet", its cells a line each)
 *            part = ("chart", its bars)
 *
 * (the two kinds' names are Part_sheet.kind and Part_chart.kind.) The
 * types say the rest. The record is the same for the two, with the
 * part's type a parameter, so what is saved cannot forget a field of
 * what is edited. A body is texts or one part, never both: a
 * spreadsheet document is a Part_sheet as large as the page, the
 * same part that floats, small, on a letter. And an object in the
 * list is in front of those before it: the list's order is the
 * depth, as a drawing's (Drawing.mli).
 *
 * Where it stands. Office_model keeps a history of these (Undo), so a
 * document must be a value: every edit in Office_edit makes a new
 * one. Office_page says where its text and objects are on a page,
 * Office_view draws them, File_menu and Saved write [saved].
 *
 * terminology:
 * Embedding and linking, OLE's two words. An object embedded is in
 * the document: the sheet above, saved inside the letter, gone with
 * it. An object linked is elsewhere and the document holds how to
 * find it: the chart holds no numbers of its own to trust, only
 * which sheet they come from, and is made again from that sheet
 * ([refreshed]). A link can break, which embedding cannot: delete
 * the sheet and the chart keeps the last bars it was given. Real
 * links go to other files, and break when a file is moved.
 *
 * others:
 * How the suites keep parts of several kinds in one file. Microsoft's
 * binary formats (Word's .doc, Excel's .xls) were a file system in a
 * file, OLE's structured storage: streams and directories of them,
 * an embedded object a directory of its own that only its program
 * read. Their successors and OpenDocument are a zip archive of XML
 * files, a part a file, pictures as they came. Both are this
 * record's idea with a container round it: each part's bytes behind
 * its kind's name, read back by whoever knows the kind.
 *
 * References: docs/plans/plan_office.md; Component.mli for a part and
 * the registry; the playground's TinyOffice, which this was a
 * section of. *)

type kind = Document | Spreadsheet | Presentation | Picture | Drawing_doc

(* where a chart takes its numbers from: the sheet that is the
   document, or a sheet object, by its id *)
type link = Main_sheet | Sheet_object of int

(* how the text goes round an object, Word's choices: on its wider side
   only, on both, above and below it only, or not at all *)
type wrap = Wider_side | Both_sides | Top_and_bottom | In_front

(* an object floating on the page: its part, the slide it is on, its
   top-left corner and size (the page's coordinates, y down), and
   whether a part with a size of its own is scaled to it. Its id stays
   the same as objects come and go, for a chart to find its sheet by.
   Tied to a paragraph ([anchor], the offset where the paragraph
   starts), its y is from the top of that paragraph's line, so that it
   moves with the text. The part is a parameter only for saving: a
   document saved is the same records with (kind, saved text) where
   each part was -- a part being functions (see [saved] below). *)
type 'p placed = {
  id : int;
  part : 'p;
  slide : int;
  x : float;
  y : float;
  w : float;
  h : float;
  scaled : bool;
  anchor : int option;
  link : link option;
  wrap : wrap;
}

type obj = Component.part placed

(* what the document is before anything floats on it: a text per slide
   (a document is one slide), or a part of its own kind *)
type 'p body_ = Texts of Rich.t list | Main of 'p

(* which text the keys go to: the body, or the header or footer of a
   document -- on the page it was clicked on, for its caret *)
type area = Body | Header of int | Footer of int

(* a page's two bands (ix: a type, where they were `Header and `Footer) *)
type band = Head | Foot

(* a document's header and footer, the same on every page, with fields
   in them -- {page} and {pages} -- that each page fills in; [scroll]:
   how far down the document's pages are scrolled *)
type 'p doc_ = { kind : kind; body : 'p body_; objects : 'p placed list; slide : int; header : Rich.t; footer : Rich.t; area : area; scroll : float }

type doc = Component.part doc_

(* A document is saved as the same records with each part replaced by
   its kind and what it saves -- whatever kind the document is, one
   file type, as the suite's own formats hold any kind of object. Open
   reads the parts back through the registry. *)
type saved = (string * string) doc_

val kinds : kind list

val name : kind -> string

(* a chart made again from its sheet, if its sheet is still there *)
val refreshed : doc -> obj -> obj

(* all of a document's charts *)
val refresh : doc -> doc

(* what its files are: the line they start with ("TinyOffice 1": the
   number goes up when the saved type changes), their names' end
   (".office") *)
val file_kind : File_menu.kind

(* the kinds of part this program reads back, each with its load *)
val registry : Component.registry

(* the charts made again from their sheets, then each part its kind and
   the text it saves *)
val to_saved : doc -> saved

(* each part read back by its kind ([registry]) *)
val of_saved : saved -> doc
