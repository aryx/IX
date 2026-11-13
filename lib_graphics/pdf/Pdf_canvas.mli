(* Pdf_canvas is the paper: an opaque picture that shapes, pictures
   and gradients are painted on, inside a clip.

   Everything a page draws comes down to four things, each cut by the
   current *clip*:

     [fill]    fills polygons (a path's curves made into lines) in a
               colour, by the nonzero or the even-odd rule, with their
               edges smoothed: a pixel is painted by how much of it
               the shape covers
     [image]   puts a picture's unit square on the paper by a
               transform, which may turn, stretch or mirror it
     [shade]   paints every pixel in a colour that depends on where
               it is: a gradient
     [blend]   is under all three, and does "over": it lays the colour
               on what is there, by its coverage times its transparency

   A stroke is a fill of its outline (Stroke.contours), and a letter
   is a fill of its contours.

   The clip is the region that the page asked painting to be kept
   inside. When the clipping path is a rectangle along the axes (most
   are, such as a page's edge or a table's cell), the clip is a box of
   pixels. Otherwise it is the box and, for each of its pixels, how
   much the path covers. A clip inside a clip multiplies the two.

   A shape's coverage is found by filling it white on a black scratch
   picture (a Framebuffer, with Fill.polygons_aa), reading its box, and
   wiping it. So the cost of a letter is its box, not the page.

   cs-history:
   Paths filled by one of two rules, under a transform, inside a clip,
   are PostScript's imaging model (Warnock and Geschke, 1984; before
   it, Warnock and Wyatt's "A device independent graphics imaging
   model for use with raster devices", SIGGRAPH 1982). Transparency
   came to PDF only in 1.4 (2001); until then, a page was paint that
   hides what is under it. "Over" is Porter and Duff's (Compositing
   Digital Images, SIGGRAPH 1984).

   Reference: ISO 32000-1:2008, sections 8.5 (paths) and 11
   (transparency). *)
(* ix: from mini-chrome's libs/pdf/Pdf_canvas.mli. The paper's pixels are
 * bytes here, where mini-chrome had floats in an array
 * (docs/plans/done/plan_pdf.md) *)

type point = float * float

type t = {
  width : int;
  height : int;
  (* four bytes for each pixel: red, green, blue, and an alpha that
   * stays 255, since a page is opaque *)
  pixels : Bytes.t;
  scratch : Framebuffer.t;
}

type clip

(* white paper *)
val create : width:int -> height:int -> t

(* the clip that is only the paper's edges *)
val everywhere : t -> clip

val fill : t -> clip -> even_odd:bool -> point list list -> float * float * float -> float -> unit

(* a shape's coverage, kept to be laid again elsewhere (as for a glyph).
 * [mask t polygons] is the coverage of the polygons inside the paper,
 * its pixels counted from (left, top). [lay t c m ~x ~y color alpha]
 * lays it with its pixel (0, 0) at (x, y), as [fill] would have filled
 * the shape moved there *)
type mask = { left : int; top : int; width : int; height : int; levels : Bytes.t }

val mask : t -> point list list -> mask
val lay :
  t -> clip -> mask -> x:int -> y:int -> float * float * float -> float -> unit

(* [clip_box c x0 y0 x1 y1] and [clip_shape t c ~even_odd polygons] make
 * the clip smaller, by a box or by a shape *)
val clip_box : clip -> float -> float -> float -> float -> clip

val clip_shape : t -> clip -> even_odd:bool -> point list list -> clip

(* [image t c m ~w ~h sample alpha] paints a picture of w by h whose
 * pixel (x, y), counted from its top left, is [sample x y] (red, green
 * and blue from 0 to 255, and opacity from 0 to 1). m puts the
 * picture's unit square on the paper, with the picture's bottom left
 * at (0, 0) *)
val image : t -> clip -> Affine.t -> w:int -> h:int -> (int -> int -> float * float * float * float) -> float -> unit

(* [shade t c color alpha] paints every pixel that the clip allows in
 * the colour given for its centre; a pixel given None is left as it
 * is *)
val shade : t -> clip -> (float -> float -> (float * float * float) option) -> float -> unit

(* the paper as a picture. It has the same bytes, not a copy, so what is
 * painted on the paper afterwards is painted on the picture too *)
val to_image : t -> Rgba_image.t
