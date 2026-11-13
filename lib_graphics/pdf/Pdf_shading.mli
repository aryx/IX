(* Pdf_shading paints gradients: a colour that changes along a line or
   between two circles.

   A flat colour is one fill. A sky, a button's sheen, and a chart's
   shadow are *shadings*: the colour at a point is a function of where
   the point is.

     axial (type 2)    The shading has a line from (x0, y0) to
                       (x1, y1). The point is dropped onto it, and its
                       colour is the function's value at how far along
                       the line it falls, from 0 to 1.
     radial (type 3)   The shading has two circles. The point is on one
                       of the circles between them, and its colour is
                       the function's value at how far that circle is
                       from the first to the second. It looks like a
                       cone seen from above, or rings when both
                       circles have one centre.

   Past the ends, the first or last colour goes on if the shading says
   so (/Extend); otherwise nothing is painted.

   The function ([apply]) is one of PDF's:

     type 2   goes from one colour to another, by a power (1 is a
              straight mix): one step of a gradient
     type 3   puts several functions end to end, each on its part of
              0..1: a gradient of several stops
     type 0   is a table of samples

   A shading is painted over all that the clip allows (the operator
   "sh"), or it is the "colour" that a path is filled with (a pattern
   of type 2, where Pdf_render clips to the path, then paints).

   It is painted pixel by pixel, each pixel's centre being taken back
   to the shading's own coordinates.

   Not done: shadings on meshes of triangles and patches (types 4 to
   7), function-based shadings (type 1), and functions written as
   PostScript (type 4).

   cs-history:
   Shadings came with PostScript Level 3 (1997) and PDF 1.3 (Acrobat 4,
   1999). Before them, a gradient in a file was hundreds of thin
   rectangles, each a little lighter than the last, and it showed as
   bands.

   Reference: ISO 32000-1:2008, sections 8.7.4 (shadings) and 7.10
   (functions). *)
(* ix: from mini-chrome's libs/pdf/Pdf_shading.mli. paint's canvas and
 * clip are a pair, because mini-ml's arm code takes 7 parameters at
 * most (docs/plans/done/plan_pdf.md) *)

(* a function's values at a number, one for each component of the
 * colour *)
val apply : Pdf.t -> Pdf_object.t -> float -> float list

(* [paint pdf (canvas, clip) ~resources ~alpha ~flat shading m] paints
 * the shading where the clip allows; m takes its coordinates to the
 * paper's pixels. With [flat], its middle colour is painted everywhere
 * (the rendering without gradients) *)
val paint : Pdf.t -> Pdf_canvas.t * Pdf_canvas.clip -> resources:Pdf_object.t -> alpha:float -> flat:bool -> Pdf_object.t -> Affine.t -> unit
