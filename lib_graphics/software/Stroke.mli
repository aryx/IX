(* Thick lines ("stroking", in PostScript's vocabulary): Line draws
 * lines 1 pixel wide, but a line [width] pixels wide is an *area*: all
 * the points within width/2 of the line. So it's drawn by turning it
 * into polygons and filling them. Each segment gives the rectangle
 * around it, and each point gives a disk of diameter [width], which
 * rounds the ends and fills the notches where two segments meet at an
 * angle:
 *
 *        +--------------------+         +-----+      the corner
 *      (      segment p0-p1     )   ... | ... |      of 2 rectangles
 *        +--------------------+         +-----+      leaves a notch
 *       ^                      ^
 *     disk                    disk     (round "joins" and "caps")
 *
 * All the rectangles and disks are filled in one Fill.polygons call,
 * after turning them all the same way, so with the Nonzero rule the
 * result is their union: each pixel is painted once, even where they
 * overlap (see Fill.polygons).
 *
 * Where it stands: this module gives a width to a game's lines
 * (lib_playground's Shape_render_software), to the stroke of an SVG
 * shape (Svg) and to a PDF path painted by S (Pdf_render). It also
 * draws Hershey's letters, which are nothing but strokes.
 *
 * terminology:
 * Fill and stroke, cap and join are PostScript's words, which PDF,
 * SVG and the web's canvas kept. To fill is to paint a path's inside;
 * to stroke is to paint a band along the path itself. A cap is how
 * the band ends (butt: it is cut at the point; square: it goes half a
 * width further; round). A join is how the band turns a corner
 * (miter: the two edges are continued to a point; bevel: the corner
 * is cut; round). Only the round ones are here. They are a disk at
 * each point, and they need no special case for a sharp corner,
 * where a miter's point goes off to infinity and must be limited.
 *
 * Reference: Adobe Systems, "PostScript Language Reference Manual",
 * Addison-Wesley, 1985 (stroke, line width, round joins and caps). *)
(* ix: the author's playground's libs/graphics/2d/Stroke.mli (docs/plans/done/plan_playground.md) *)

(* The rectangles and disks of [lines] (each line is a list of points,
 * in pixel coordinates, joined by segments), all turned the same way.
 * They are to be filled with the Nonzero rule, e.g. with
 * Fill.polygons_aa for antialiased strokes. *)
val contours : (float * float) list list -> width:float -> (float * float) list list

(* [polylines fb lines ~width ~rgb ~alpha] fills the [contours] of
 * [lines] with Fill.polygons. *)
val polylines :
  Framebuffer.t -> (float * float) list list -> width:float -> rgb:int -> alpha:float -> unit
