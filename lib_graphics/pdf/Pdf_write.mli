(* Pdf_write: a PDF file written -- its objects numbered, its pages
 * listed, and the table at its end saying where each object starts.
 *
 * A PDF file is numbered objects that name each other ("5 0 R"), and
 * a table of the byte each starts at:
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
 * The first three are the same in every file written here: the
 * catalog, the pages' tree (one node, every page under it) and one
 * dictionary of what the pages' contents name, shared by all of them
 * (the opacities, the pictures, the forms). They are written last,
 * when what they list is known; a reader starts from the table, so
 * the order in the file is free.
 *
 * A page's *content* is a list of drawing operators, each after its
 * operands (Pdf_render, when it is here, runs them):
 *
 *   0.8 0.1 0.1 rg                 a colour to fill with
 *   20 20 m 120 20 l 120 80 l h f  a path, closed and filled
 *
 * in points (1/72 inch), the origin at the page's bottom left, y up.
 * The functions below add operators to a [content]; nothing is
 * checked of their order, which is the caller's (a path, then what
 * paints it).
 *
 * The same bytes whatever compiles it: a number is written by integer
 * arithmetic, in hundredths; the file has no date and no identifier.
 *
 * Not written: text in a font (letters are drawn by their strokes,
 * for now: docs/plans/plan_pdf.md, stage E), an outline, links.
 *
 * The table at the end is made to be read without being parsed: a
 * line an object, each of exactly 20 bytes,
 *
 *     xref
 *     0 6                      objects 0 to 5 follow
 *     0000000000 65535 f       object 0: never one (the free list's head)
 *     0000000015 00000 n       object 1 starts at byte 15 of the file
 *     ...
 *     10 digits, a space, 5 digits, a space, n or f, a space, a newline
 *
 * so the entry of object k is 20 k bytes after the first, and the
 * table's start is the number on the line before the last. A writer
 * only has to remember, as it writes each object, how many bytes it
 * has written so far: that is all the table asks of it.
 *
 * Where it stands in ix: the last stage of mini-office's File >
 * Export (Office_export). A document's parts draw themselves as the
 * playground's shapes, for the screen and for the file alike;
 * Shape_render_pdf turns each shape into the calls below where
 * Shape_render_software turns it into pixels (Fill, Stroke). So the
 * file is the screen's drawing, as paths, and stays sharp when
 * printed. Under it Zlib.deflate, when the streams are compressed.
 * The reading side (Pdf, Pdf_render) shares no code with it, and is
 * its test: a file written here is read and drawn there.
 *
 * design:
 * A format one can write with a print statement. To read PDF takes
 * the fifteen modules beside this one and of the fonts, since a
 * reader must take whatever any writer chose among the format's
 * many ways; a writer chooses one way of each and is this file
 * alone. It is why every program has had an export to PDF and few a
 * viewer, and how PostScript spread before it: a program printed by
 * writing text.
 *
 * Reference: ISO 32000-1:2008 (PDF 1.7), sections 7.5 (file
 * structure), 7.7 (document structure), 8 (graphics). *)

type t

(* a file with no page yet; [compress]: each stream deflated (Zlib),
 * else left as it is, to be read by eye *)
val create : compress:bool -> t

(* the file's bytes *)
val to_string : t -> string

(*****************************************************************************)
(* A content: operators, one after the other *)
(*****************************************************************************)

type content

val content : unit -> content

(* "q" and "Q": the graphics state (transform, colours, pen, opacity)
 * kept, and what was kept put back *)
val save : content -> unit
val restore : content -> unit

(* "cm": what follows is drawn through the transform too *)
val transform : content -> Affine.t -> unit

(* "rg" and "RG": the colour, 0xRRGGBB, that fills and that strokes *)
val fill_color : content -> int -> unit
val stroke_color : content -> int -> unit

(* "w", with "J" and "j": the pen's width, its ends and corners round *)
val pen : content -> float -> unit

(* "gs": how opaque what follows is, 0 to 1, fills and strokes *)
val opacity : t -> content -> float -> unit

(* a path: its points joined, closed ([polygon]) or not ([polyline]: a
 * single point is a dot of the pen's width) *)
val polygon : content -> (float * float) list -> unit
val polyline : content -> (float * float) list -> unit

(* [ellipse c m ~rx ~ry]: the ellipse of those radii about (0, 0), put
 * on the page by m: four curves *)
val ellipse : content -> Affine.t -> rx:float -> ry:float -> unit

(* "f" and "S": the path filled (nonzero), stroked by the pen *)
val fill : content -> unit
val stroke : content -> unit

(*****************************************************************************)
(* What a content names: pictures and forms *)
(*****************************************************************************)

(* something drawn by its name ("Do") *)
type named

(* a picture's pixels, kept in the file once; drawn, it covers the unit
 * square, its bottom left at (0, 0): a [transform] before puts it
 * where it goes. Its transparency is kept, if it has any *)
val picture : t -> Rgba_image.t -> named

(* [form t (x0, y0, x1, y1) c]: a content kept in the file once and
 * drawn as often as wanted, cut to that box: what several pages share *)
val form : t -> float * float * float * float -> content -> named

val draw : content -> named -> unit

(*****************************************************************************)
(* Pages *)
(*****************************************************************************)

(* a page of that size in points, after those already there *)
val page : t -> width:float -> height:float -> content -> unit
