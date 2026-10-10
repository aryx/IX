(* Pdf_canvas: the paper -- an opaque picture that shapes, pictures
   and gradients are painted on, inside a clip.

   Everything a page draws comes down to four things, each cut by the
   current *clip*:

     [fill]    polygons (a path's curves made lines) in a colour, by
               the nonzero or the even-odd rule, their edges smoothed:
               a pixel is painted by how much of it the shape covers
     [image]   a picture, its unit square put on the paper by a
               transform -- turned, stretched, mirrored
     [shade]   every pixel in a colour that depends on where it is: a
               gradient
     [blend]   and under all three, "over": the colour laid on what is
               there, by its coverage times its transparency

   A stroke is a fill of its outline (tiny_libs' Stroke); a letter, a
   fill of its contours.

   The clip is what the page asked painting to be kept inside: a box
   of pixels when the clipping path is a rectangle along the axes
   (most are: a page's edge, a table's cell), else the box and, for
   each of its pixels, how much the path covers. A clip inside a clip
   multiplies.

   A shape's coverage is found by filling it white on a black scratch
   picture (tiny_libs' Fill.polygons_aa), reading its box, and wiping
   it: the cost of a letter is its box, not the page.

   cs-history:
   Paths filled by one of two rules, under a transform, inside a clip:
   PostScript's imaging model (Warnock and Geschke, 1984; before it,
   Warnock and Wyatt's "A device independent graphics imaging model
   for use with raster devices", SIGGRAPH 1982). Transparency came
   to PDF only in 1.4 (2001): until then a page was paint that hides
   what is under it. "Over" is Porter and Duff's (Compositing Digital
   Images, SIGGRAPH 1984).

   Reference: ISO 32000-1:2008, sections 8.5 (paths), 11 (transparency). *)
(* ix: mini-chrome's libs/pdf/Pdf_canvas.mli; the paper's pixels are bytes, where they were floats in an array (docs/plans/plan_pdf.md) *)

type point = float * float

type t = {
  width : int;
  height : int;
  pixels : Bytes.t; (* red, green, blue of each pixel, a byte each (ix: they were floats) *)
  scratch : Framebuffer.t;
}

type clip

(* white paper *)
val create : width:int -> height:int -> t

(* no clip but the paper's edges *)
val everywhere : t -> clip

val fill : t -> clip -> even_odd:bool -> point list list -> float * float * float -> float -> unit

(* [clip_box c x0 y0 x1 y1], [clip_shape t c ~even_odd polygons]: the clip made smaller *)
val clip_box : clip -> float -> float -> float -> float -> clip

val clip_shape : t -> clip -> even_odd:bool -> point list list -> clip

(* [image t c m ~w ~h sample alpha]: a picture of w by h whose pixel
 * (x, y), from its top left, is [sample x y] (red, green, blue, 0 to
 * 255; opacity, 0 to 1); m puts its unit square, the picture's bottom
 * left at (0, 0), on the paper *)
val image : t -> clip -> Affine.t -> w:int -> h:int -> (int -> int -> float * float * float * float) -> float -> unit

(* [shade t c color alpha]: every pixel the clip allows, in the colour
 * given for its centre (none: left as it is) *)
val shade : t -> clip -> (float -> float -> (float * float * float) option) -> float -> unit

(* the paper as a picture: the same bytes, not a copy (what is painted
 * on the paper after is painted on the picture) *)
val to_image : t -> Rgba_image.t
