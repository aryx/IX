(* Pdf_write writes a PDF file: it numbers its objects, lists its
 * pages, and writes the table at its end that says where each object
 * starts.
 *
 * A PDF file is made of numbered objects that name each other
 * ("5 0 R"), and a table of the byte that each one starts at:
 *
 *   %PDF-1.4
 *   1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
 *   2 0 obj << /Type /Pages /Kids [5 0 R] /Count 1 >> endobj
 *   3 0 obj << /ExtGState << ... >> /XObject << ... >> >> endobj
 *   4 0 obj << /Length 44 >> stream ... endstream endobj
 *   5 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]
 *              /Resources 3 0 R /Contents 4 0 R >> endobj
 *   xref ... trailer << /Size 6 /Root 1 0 R >> startxref 512 %%EOF
 *
 * The first three objects are the same in every file written here:
 * the catalog, the pages' tree (one node, with every page under it),
 * and one dictionary of what the pages' contents name, shared by all
 * of them (the opacities, the pictures, the forms). They are written
 * last, when what they list is known. A reader starts from the table,
 * so the order in the file is free.
 *
 * A page's *content* is a list of drawing operators, each after its
 * operands (Pdf_render runs them):
 *
 *   0.8 0.1 0.1 rg                 set a colour to fill with
 *   20 20 m 120 20 l 120 80 l h f  make a path, close it and fill it
 *
 * The numbers are in points (1/72 inch), with the origin at the
 * page's bottom left and y going up. The functions below add
 * operators to a [content]. Their order is not checked; it is the
 * caller's job (a path, then what paints it).
 *
 * The bytes are the same whatever compiles this module: a number is
 * written by integer arithmetic, in hundredths, and the file has no
 * date and no identifier.
 *
 * Text is written in a font that the reader has. The file names it
 * (Times-Roman, Helvetica-Bold, Courier: Standard_widths.mli) and
 * carries no letter's shape, as a file could from the first PDF on.
 * Its characters are the 217 of Windows' encoding. (mini-office's
 * letters are still drawn by their strokes: docs/plans/done/plan_pdf.md,
 * stage E.) A font carried in the file, an outline, and links are not
 * written.
 *
 * The table at the end is made to be read without being parsed. It
 * has a line for each object, each line of exactly 20 bytes:
 *
 *     xref
 *     0 6                      objects 0 to 5 follow
 *     0000000000 65535 f       object 0: never one (the free list's head)
 *     0000000015 00000 n       object 1 starts at byte 15 of the file
 *     ...
 *     10 digits, a space, 5 digits, a space, n or f, a space, a newline
 *
 * So the entry of object k is 20 k bytes after the first, and the
 * table's start is the number on the line before the last. A writer
 * only has to remember, as it writes each object, how many bytes it
 * has written so far: that is all the table asks of it.
 *
 * Where it stands in ix: it is the last stage of mini-office's File >
 * Export (Office_export). A document's parts draw themselves as the
 * playground's shapes, for the screen and for the file alike.
 * Shape_render_pdf turns each shape into the calls below, where
 * Shape_render_software turns it into pixels (Fill, Stroke). So the
 * file is the screen's drawing, as paths, and stays sharp when
 * printed. Under it is Zlib.deflate, when the streams are compressed.
 * The reading side (Pdf, Pdf_render) shares no code with it, and is
 * its test: a file written here is read and drawn there.
 *
 * design:
 * PDF is a format one can write with a print statement. Reading PDF
 * takes the fifteen modules beside this one and the fonts' modules,
 * since a reader must take whatever any writer chose among the
 * format's many ways. A writer chooses one way for each thing and is
 * this file alone. This is why every program has had an export to PDF
 * and few have had a viewer, and it is how PostScript spread before
 * it: a program printed by writing text.
 *
 * Reference: ISO 32000-1:2008 (PDF 1.7), sections 7.5 (file
 * structure), 7.7 (document structure) and 8 (graphics). *)

type t

(* a file with no page yet. With [compress], each stream is deflated
 * (Zlib); otherwise it is left as it is, to be read by eye *)
val create : compress:bool -> t

(* the file's bytes *)
val to_string : t -> string

(*****************************************************************************)
(* A content: operators, one after the other *)
(*****************************************************************************)

type content

val content : unit -> content

(* "q" and "Q": [save] keeps the graphics state (transform, colours,
 * pen, opacity), and [restore] puts back what was kept *)
val save : content -> unit
val restore : content -> unit

(* "cm": what follows is drawn through this transform too *)
val transform : content -> Affine.t -> unit

(* "rg" and "RG" set the colour, 0xRRGGBB, that fills and that strokes *)
val fill_color : content -> int -> unit
val stroke_color : content -> int -> unit

(* "w", with "J" and "j", sets the pen's width, and makes its ends and
 * corners round *)
val pen : content -> float -> unit

(* "gs" sets how opaque what follows is, from 0 to 1, for fills and
 * strokes *)
val opacity : t -> content -> float -> unit

(* adds a path that joins the points, closed ([polygon]) or not
 * ([polyline], where a single point is a dot of the pen's width) *)
val polygon : content -> (float * float) list -> unit
val polyline : content -> (float * float) list -> unit

(* [ellipse c m ~rx ~ry] adds the ellipse of those radii about (0, 0),
 * put on the page by m, as four curves *)
val ellipse : content -> Affine.t -> rx:float -> ry:float -> unit

(* "f" and "S": [fill] fills the path (by the nonzero rule), and
 * [stroke] strokes it with the pen *)
val fill : content -> unit
val stroke : content -> unit

(* "BT ... Tf ... Td (...) Tj ET": [text file c ~font ~size (x, y) s]
 * writes s (UTF-8) from (x, y), which is the left of its first letter,
 * on the line that the letters stand on. It is in the font of that
 * name at that size, in the fill's colour. A character that the
 * encoding does not have is written "?". [writes] says, of a
 * character's number, whether the encoding has it. *)
val text : t -> content -> font:string -> size:float -> float * float -> string -> unit
val writes : int -> bool

(*****************************************************************************)
(* What a content names: pictures and forms *)
(*****************************************************************************)

(* something drawn by its name ("Do") *)
type named

(* a picture's pixels, kept in the file once. When it is drawn, it
 * covers the unit square, with its bottom left at (0, 0), and a
 * [transform] before it puts it where it goes. Its transparency is
 * kept, if it has any *)
val picture : t -> Rgba_image.t -> named

(* [form t (x0, y0, x1, y1) c] is a content kept in the file once and
 * drawn as often as wanted, cut to that box. Several pages can share
 * it this way *)
val form : t -> float * float * float * float -> content -> named

val draw : content -> named -> unit

(*****************************************************************************)
(* Pages *)
(*****************************************************************************)

(* adds a page of that size in points, after the pages already there *)
val page : t -> width:float -> height:float -> content -> unit
