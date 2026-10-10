(* Pdf_render: a page drawn -- its content's operators run, one after
   the other, onto a canvas.

   A page's content is a list of operators, each after its operands:

     q                         save the graphics state
     1 0 0 1 72 720 cm         move the origin (the transform, "CTM")
     0.8 0.1 0.1 rg            a fill colour
     0 0 100 50 re f           a rectangle, filled
     BT /F1 12 Tf              text: a font at a size
       10 20 Td (Hello) Tj     a place, a string shown
     ET
     Q                         restore

   no loop, no variable, no condition: PostScript's picture without
   PostScript's programs, so that a page can be drawn without running
   the ones before it, and in a time one can bound. The interpreter
   is a loop over the words, a stack of operands, and a *graphics
   state*:

     the transform   user space (points, y up) to the paper's pixels
     the clip        where painting is allowed (Pdf_canvas)
     two colours     to fill, to stroke (Pdf_color)
     a line's width
     the text state  font and size, spacing, and the *text matrix*:
                     where the next glyph goes

   Paths ("m l c h re") are built point by point, curves made lines at
   once, in pixels; then one operator paints them ("f", "S", "B") or
   only makes them the clip ("W n").

   Text: each code of a string is a glyph of the font (Pdf_font),
   placed by the text matrix times the transform; the matrix is then
   moved by the glyph's width. "TJ" shows strings with small moves
   between them: the kerning and the justified spaces, which the
   program that made the file computed. So a renderer does no layout
   at all -- no line breaking, no word spacing: every glyph is where
   it was put.

   What is drawn in full can be drawn plainly instead, to see what
   each refinement adds ([options]; the browser's flag pdf=):

     letters        the file's own fonts' outlines, or [Strokes]: our
                    stroke font at the file's widths -- the words where
                    they belong, in letters that are not theirs
     gradients      or each one's middle colour
     clips          or everything painted whole
     pictures       or a grey box
     transparency   or all opaque

   [plain] is all of them off: the simple code path.

   The words of a page ([text]) are the same run with nothing painted:
   each glyph's characters where it was shown, a space where the pen
   jumped, a new line where it went down.

   Not done: tiling patterns (grey), dashed lines, line caps and
   joins other than round, blend modes and soft masks of a group,
   text as a clip, optional content (layers), annotations.

   modern:
   A real viewer does not redo this at each scroll: the page is
   turned once into a list of drawing commands, and those are painted
   by the same library as the web page's (Skia in Chrome), on the
   graphics card, in tiles. Here a page is one picture, made when it
   comes into view.

   Where it stands in ix: between Pdf, which gives a page's content
   and what it names (fonts, pictures, shadings), and Pdf_canvas,
   which paints. Called by mini-page (Pageview) and by the browser's
   viewer (Pdf_viewer), a page at a time; its opposite is Pdf_write,
   whose functions write the operators this one runs.

   design:
   Three little stack machines in a PDF, all Adobe's and all written
   operands first: this one, for a page (the format has some seventy
   operators, and no jump); a Type 1 glyph's (Type1.mli) and a CFF
   glyph's (Cff.mli), each with a few dozen and subroutines. A fourth, the
   instructions of a TrueType glyph (Truetype.mli), is Apple's and
   is not run. Each is PostScript with something taken out until
   what is left can be run without fear: no loop, so a page ends; no
   file or memory to reach, so a document from a stranger is safe to
   open. The power that was taken out is why PDF could be an archive's
   format and PostScript could not.

   Reference: ISO 32000-1:2008, sections 8 (graphics) and 9 (text). *)
(* ix: mini-chrome's libs/pdf/Pdf_render.mli; render's options and stroke_glyph are said, where they were optional; hershey is given (docs/plans/plan_pdf.md) *)

type letters = Outlines | Strokes

type options = {
  letters : letters;
  gradients : bool;
  clips : bool;
  pictures : bool;
  transparency : bool;
}

(* everything; and nothing but paths, colours and our letters *)
val full : options

val plain : options

(* "strokes,-gradients": words separated by commas, each turning a
 * part on, or off with a minus before it (strokes, outlines,
 * gradients, clips, pictures, transparency); "plain" and "full" all
 * at once. Starts from [full]; an unknown word is skipped *)
val options_of_string : string -> options

(* what is kept between the pages of a document: its fonts, read once *)
type cache

val cache : unit -> cache

(* a page's size in points, once turned as it says *)
val size : Pdf.page -> float * float

(* [render ~options ~stroke_glyph pdf cache page ~scale]: the page's
 * picture, [scale] pixels a point. [stroke_glyph]: a character's
 * letter in a stroke font -- the pen's paths in an em of 1, from the
 * baseline up, and how far the pen moves after it ([hershey]: ASCII).
 * (ix: the two were optional, [full] and [hershey]) *)
val render :
  options:options -> stroke_glyph:(int -> (float * float) list list * float) -> Pdf.t -> cache -> Pdf.page -> scale:float -> Rgba_image.t

(* Hershey's letter of a character, as [render]'s stroke_glyph *)
val hershey : int -> (float * float) list list * float

(* a page's words, in the order they are shown, as UTF-8 *)
val text : Pdf.t -> cache -> Pdf.page -> string
