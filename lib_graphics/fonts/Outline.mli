(* Outline: a letter's shape -- closed contours of lines and curves,
   as every outline font gives it.

   A glyph is a few *contours*, each a closed path: an "o" has two
   (the outside, and the hole, turned the other way), an "i" two that
   do not touch. A contour is a start and segments, each going on from
   where the last ended:

     a line        to a point
     a quadratic   one control point: TrueType's curves
     a cubic       two: PostScript's (Type 1, CFF)

   in the font's own units (an em of 1000 or 2048), y up, the
   baseline at 0.

   To paint one: its points through a transform (a size, a place),
   its curves made lines ([polygons]), the polygons filled -- with
   the nonzero rule, which is why the hole turns the other way.

   A font's glyph programs (Type1.mli, Cff.mli) draw with a [pen]:
   "move 10 0, line 0 50, curve ..." all relative to where it is.

   An o, its two contours and what the rule makes of them:

        .-->--.           the outside turns one way: a point in the
       /  .<.  \          ring has one crossing to its left, +1: inside
      |  (   )  |         the hole turns the other way: a point in it
       \  `>'  /          has two, +1 and -1 = 0: outside
        `--<--'

   A font that turned both the same way would give a black disk.

   Where it stands in ix: the one type between the three font
   formats and the pixels,

     Truetype (glyf: quadratics) --.
     Cff (charstrings: cubics)   ---+--> Outline.t --[polygons]--> Fill
     Type1 (charstrings: cubics) --'         Curve.flatten

   so each reader knows its file and nothing of painting, and the
   painter (Pdf_canvas, for a PDF page's text: Pdf_font finds the
   font, Pdf_render places the glyph) knows neither which format a
   letter came from nor what a curve is. A fourth format would be a
   fourth reader.

   modern:
   What a real text renderer adds between this type and the pixels.
   Hinting: the outline's points moved onto the pixel grid before
   filling, by the font's own instructions or by guessing its stems,
   so that a stem is a whole number of pixels wide: what made small
   text readable at 96 dots an inch. A cache: a glyph at a size is
   filled once and kept as a small picture of coverage, then drawn
   by a copy through it as a mask (what Font does with Plan 9's
   pictures of letters, by Draw.draw). Shaping: which glyphs a
   string is, with its ligatures and marks, before any is drawn.
   Here a glyph is filled again each time it is shown, with none of
   the three.

   cs-history:
   Both curves are Bezier's (Pierre Bezier, Renault, and Paul de
   Casteljau, Citroen, around 1960: car bodies). Apple took the
   quadratic for TrueType -- cheaper to draw on a machine of 1990;
   Adobe had the cubic since PostScript. A quadratic is a cubic whose
   two control points are two thirds of the way to its one. *)
(* ix: mini-chrome's libs/fonts/Outline.mli; polygons' tolerance is said, where it was optional (Curve's 0.1) (docs/plans/plan_pdf.md) *)

type point = float * float
type segment = Line of point | Quadratic of point * point | Cubic of point * point * point
type contour = { start : point; segments : segment list }
type t = contour list

(* [polygons ~tolerance f o]: each contour as a closed polygon, its
 * points through f, its curves lines no further than [tolerance]
 * from them (after f: in pixels, a tenth unless said) *)
val polygons : tolerance:float -> (point -> point) -> t -> point list list

(* left, bottom, right, top; none for a glyph that draws nothing (a space) *)
val bounds : t -> (float * float * float * float) option

(* a pen: where it is, the contour it is drawing, those it has finished *)
type pen = { mutable x : float; mutable y : float; mutable current : (point * segment list) option; mutable finished : contour list }

val pen : unit -> pen

(* the pen moved by a step, ending the contour it was in *)
val move : pen -> float -> float -> unit

(* a line, and a curve (three steps: to each control point, to the end), from where it is *)
val line : pen -> float -> float -> unit

val curve : pen -> float -> float -> float -> float -> float -> float -> unit

(* a segment given whole, to where it ends *)
val add : pen -> segment -> unit

(* the contour it is in, ended *)
val close : pen -> unit

(* what it drew *)
val drawn : pen -> t
