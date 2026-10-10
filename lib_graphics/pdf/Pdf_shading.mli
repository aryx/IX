(* Pdf_shading: gradients -- a colour that changes along a line or
   between two circles.

   A flat colour is one fill. A sky, a button's sheen, a chart's
   shadow are *shadings*: the colour at a point is a function of
   where the point is.

     axial (type 2)    a line from (x0, y0) to (x1, y1): the point is
                       dropped onto it, and its colour is the
                       function's at how far along it falls, 0 to 1
     radial (type 3)   two circles: the point is on one of the circles
                       between them, and its colour is the function's
                       at how far that circle is from the first to
                       the second. A cone seen from above; with one
                       centre, rings

   Past the ends, the first or last colour goes on if the shading
   says so (/Extend), else nothing is painted.

   The function ([apply]) is one of PDF's:

     type 2   from one colour to another, by a power (1: a straight
              mix) -- one step of a gradient
     type 3   several functions end to end, each on its part of 0..1
              -- a gradient of several stops
     type 0   a table of samples

   A shading is painted over all that the clip allows (the operator
   "sh"), or is the "colour" a path is filled with (a pattern of type
   2: Pdf_render clips to the path, then paints).

   Painted pixel by pixel: each pixel's centre taken back to the
   shading's own coordinates.

   Not done: shadings on meshes of triangles and patches (types 4 to
   7), function-based ones (1), functions written as PostScript (4).

   cs-history:
   PostScript Level 3 (1997) and PDF 1.3 (Acrobat 4, 1999). Before, a gradient
   in a file was hundreds of thin rectangles each a little lighter
   than the last, and it showed: bands.

   Reference: ISO 32000-1:2008, sections 8.7.4 (shadings) and 7.10
   (functions). *)
(* ix: mini-chrome's libs/pdf/Pdf_shading.mli; paint's canvas and clip are a pair (mini-ml's arm code takes 7 parameters at most) (docs/plans/plan_pdf.md) *)

(* a function's values at a number: one a component of the colour *)
val apply : Pdf.t -> Pdf_object.t -> float -> float list

(* [paint pdf (canvas, clip) ~resources ~alpha ~flat shading m]: the
 * shading painted where the clip allows; m takes its coordinates to
 * the paper's pixels. [flat]: its middle colour everywhere (the
 * rendering without gradients) *)
val paint : Pdf.t -> Pdf_canvas.t * Pdf_canvas.clip -> resources:Pdf_object.t -> alpha:float -> flat:bool -> Pdf_object.t -> Affine.t -> unit
