(* Outline is a letter's shape: closed contours of lines and curves,
   as every outline font gives it.

   A glyph is a few *contours*, and each is a closed path. An "o" has
   two (the outside, and the hole, which turns the other way), and an
   "i" has two that do not touch. A contour is a start and segments,
   each going on from where the last one ended:

     a line        to a point
     a quadratic   one control point: TrueType's curves
     a cubic       two: PostScript's (Type 1, CFF)

   The points are in the font's own units (an em of 1000 or 2048), with
   y going up and the baseline at 0.

   To paint a glyph, its points go through a transform (a size, a
   place), its curves are made lines ([polygons]), and the polygons are
   filled with the nonzero rule, which is why the hole turns the other
   way.

   A font's glyph programs (Type1.mli, Cff.mli) draw with a [pen]:
   "move 10 0, line 0 50, curve ...", all relative to where it is.

   Here is an o, its two contours, and what the rule makes of them:

        .-->--.           the outside turns one way: a point in the
       /  .<.  \          ring has one crossing to its left, +1: inside
      |  (   )  |         the hole turns the other way: a point in it
       \  `>'  /          has two, +1 and -1 = 0: outside
        `--<--'

   A font that turned both the same way would give a black disk.

   Where it stands in ix: it is the one type between the three font
   formats and the pixels,

     Truetype (glyf: quadratics) --.
     Cff (charstrings: cubics)   ---+--> Outline.t --[polygons]--> Fill
     Type1 (charstrings: cubics) --'         Curve.flatten

   so each reader knows its file and nothing of painting. The painter
   (Pdf_canvas, for a PDF page's text, where Pdf_font finds the font
   and Pdf_render places the glyph) knows neither which format a letter
   came from nor what a curve is. A fourth format would only need a
   fourth reader.

   modern:
   A real text renderer adds three things between this type and the
   pixels.
   - Hinting: the outline's points are moved onto the pixel grid
     before filling, by the font's own instructions or by guessing its
     stems, so that a stem is a whole number of pixels wide. It is what
     made small text readable at 96 dots an inch.
   - A cache: a glyph at a size is filled once and kept as a small
     picture of coverage, then drawn by a copy through it as a mask
     (which is what Font does with Plan 9's pictures of letters, by
     Draw.draw).
   - Shaping: finding which glyphs a string is, with its ligatures and
     marks, before any is drawn.
   Here a glyph is filled again each time it is shown, with none of
   the three.

   cs-history:
   Both curves are Bezier's (Pierre Bezier at Renault and Paul de
   Casteljau at Citroen drew car bodies with them around 1960). Apple
   took the quadratic for TrueType, because it was cheaper to draw on a
   machine of 1990; Adobe had had the cubic since PostScript. A
   quadratic is a cubic whose two control points are two thirds of the
   way to its one. *)
(* ix: copied from libs/fonts/Outline.mli in mini-chrome
 * (docs/plans/done/plan_pdf.md). The tolerance of polygons must be
 * given, where it was optional (Curve's 0.1). *)

type point = float * float
type segment = Line of point | Quadratic of point * point | Cubic of point * point * point
type contour = { start : point; segments : segment list }
type t = contour list

(* [polygons ~tolerance f o] gives each contour as a closed polygon:
 * its points go through f, and its curves become lines no further than
 * [tolerance] from them (measured after f, so in pixels). There is
 * no default: Pdf_render gives 0.2, for example. *)
val polygons : tolerance:float -> (point -> point) -> t -> point list list

(* left, bottom, right, top; None for a glyph that draws nothing (a
 * space) *)
val bounds : t -> (float * float * float * float) option

(* a pen: where it is, the contour it is drawing, and the contours it
 * has finished *)
type pen = { mutable x : float; mutable y : float; mutable current : (point * segment list) option; mutable finished : contour list }

val pen : unit -> pen

(* moves the pen by a step, ending the contour it was in *)
val move : pen -> float -> float -> unit

(* draws a line, and a curve (given as three steps: to each control
 * point, then to the end), from where the pen is *)
val line : pen -> float -> float -> unit

val curve : pen -> float -> float -> float -> float -> float -> float -> unit

(* adds a segment given whole, and moves the pen to where it ends *)
val add : pen -> segment -> unit

(* ends the contour the pen is in *)
val close : pen -> unit

(* what the pen drew *)
val drawn : pen -> t
