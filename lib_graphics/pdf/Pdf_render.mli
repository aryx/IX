(* Pdf_render draws a page: it runs its content's operators, one after
   the other, onto a canvas.

   A page's content is a list of operators, each after its operands:

     q                         save the graphics state
     1 0 0 1 72 720 cm         move the origin (the transform, "CTM")
     0.8 0.1 0.1 rg            set a fill colour
     0 0 100 50 re f           fill a rectangle
     BT /F1 12 Tf              begin text, with a font at a size
       10 20 Td (Hello) Tj     go to a place, show a string
     ET
     Q                         restore

   There is no loop, no variable and no condition. This is
   PostScript's picture without PostScript's programs, so that a page
   can be drawn without running the ones before it, and in a time one
   can bound. The interpreter is a loop over the words, a stack of
   operands, and a *graphics state*:

     the transform   takes user space (points, y up) to the paper's
                     pixels
     the clip        says where painting is allowed (Pdf_canvas)
     two colours     one to fill and one to stroke (Pdf_color)
     a line's width
     the text state  has the font and size, the spacing, and the
                     *text matrix*, which says where the next glyph goes

   Paths ("m l c h re") are built point by point, in pixels, and their
   curves are made into lines at once. Then one operator paints them
   ("f", "S", "B") or only makes them the clip ("W n").

   For text, each code of a string is a glyph of the font (Pdf_font),
   placed by the text matrix times the transform; the matrix is then
   moved by the glyph's width. "TJ" shows strings with small moves
   between them, which are the kerning and the justified spaces that
   the program that made the file computed. So a renderer does no
   layout at all, no line breaking and no word spacing: every glyph is
   where it was put.

   What is drawn in full can be drawn plainly instead, to see what
   each refinement adds ([options]; the browser's flag pdf=):

     letters        the outlines of the file's own fonts, or [Strokes]:
                    our stroke font at the file's widths, which puts
                    the words where they belong, in letters that are
                    not theirs
     gradients      or each gradient's middle colour
     clips          or everything painted whole
     pictures       or a grey box
     transparency   or all opaque

   [plain] has all of them off, which is the simple code path.

   The words of a page ([text]) come from the same run with nothing
   painted. Each glyph's characters are put where it was shown, a
   space where the pen jumped, and a new line where it went down.

   Not done: tiling patterns (they are grey), dashed lines, line caps
   and joins other than round, blend modes and soft masks of a group,
   text as a clip, optional content (layers), and annotations.

   modern:
   A real viewer does not redo this at each scroll. The page is turned
   once into a list of drawing commands, and those are painted by the
   same library as the web page (Skia in Chrome), on the graphics
   card, in tiles. Here a page is one picture, made when it comes into
   view.

   Where it stands in ix: it is between Pdf, which gives a page's
   content and what it names (fonts, pictures, shadings), and
   Pdf_canvas, which paints. mini-page (Pageview) and the browser's
   viewer (Pdf_viewer) call it, a page at a time. Its opposite is
   Pdf_write, whose functions write the operators that this one runs.

   design:
   There are three little stack machines in a PDF, all Adobe's and all
   written operands first: this one, for a page (the format has some
   seventy operators, and no jump), and the machines of a Type 1 glyph
   (Type1.mli) and of a CFF glyph (Cff.mli), each with a few dozen
   operators and subroutines. A fourth, the instructions of a TrueType
   glyph (Truetype.mli), is Apple's and is not run. Each is PostScript
   with something taken out until what is left can be run without
   fear. There is no loop, so a page ends; there is no file or memory
   to reach, so a document from a stranger is safe to open. The power
   that was taken out is why PDF could be an archive's format and
   PostScript could not.

   Reference: ISO 32000-1:2008, sections 8 (graphics) and 9 (text). *)
(* ix: from mini-chrome's libs/pdf/Pdf_render.mli. render's options and
 * stroke_glyph are given explicitly, where they were optional, and
 * hershey is given here (docs/plans/done/plan_pdf.md) *)

type letters = Outlines | Strokes

type options = {
  letters : letters;
  gradients : bool;
  clips : bool;
  pictures : bool;
  transparency : bool;
}

(* [full] draws everything, and [plain] draws nothing but paths, colours
 * and our letters *)
val full : options

val plain : options

(* reads options such as "strokes,-gradients": words separated by
 * commas, each turning a part on, or off when it has a minus before it
 * (strokes, outlines, gradients, clips, pictures, transparency).
 * "plain" and "full" set all the parts at once. It starts from [full],
 * and an unknown word is skipped *)
val options_of_string : string -> options

(* what is kept between the pages of a document: its fonts, which are
 * read once *)
type cache

val cache : unit -> cache

(* a page's size in points, after it is turned as it says *)
val size : Pdf.page -> float * float

(* [render ~options ~stroke_glyph pdf cache page ~scale] is the page's
 * picture, at [scale] pixels a point. [stroke_glyph] gives a
 * character's letter in a stroke font: the pen's paths in an em of 1,
 * from the baseline up, and how far the pen moves after it ([hershey]
 * covers ASCII). (ix: the two were optional, with [full] and [hershey]
 * as defaults) *)
val render :
  options:options -> stroke_glyph:(int -> (float * float) list list * float) -> Pdf.t -> cache -> Pdf.page -> scale:float -> Rgba_image.t

(* Hershey's letter for a character, to pass as [render]'s
 * stroke_glyph *)
val hershey : int -> (float * float) list list * float

(* a page's words, in the order they are shown, as UTF-8 *)
val text : Pdf.t -> cache -> Pdf.page -> string
