(* Drawing an image (a sprite, a photo) moved, scaled, and rotated: an
 * affine transform of its pixels onto the framebuffer's pixels.
 *
 * "Blit" comes from BitBLT, "bit block transfer", the operation at the
 * heart of the Xerox Alto and Smalltalk graphics (Dan Ingalls, 1970s):
 * copying a rectangle of pixels onto another. Here it is generalized to
 * any affine transform, which the literature calls image warping.
 *
 * Forward or inverse? The obvious way is to go through the image's
 * pixels and compute where each one lands on the screen ("forward
 * mapping"). It leaves holes as soon as the image is enlarged or
 * rotated: 2 image pixels side by side land 2 screen pixels apart, and
 * nobody paints the one in between.
 *
 *    image        forward: holes       inverse: every screen pixel
 *    +--+--+      +--+--+--+--+        +--+--+--+--+
 *    |A |B |  x2  |A |  |B |  |        |A |A |B |B |
 *    +--+--+ ---> +--+--+--+--+        +--+--+--+--+
 *                 |  |  |  |  |        |A |A |B |B |
 *                 +--+--+--+--+        +--+--+--+--+
 *
 * So we go the other way ("inverse mapping"). We go through the
 * *screen's* pixels, those that the transformed image may cover, and
 * for each one we find where its center comes from in the image, with
 * the inverse transform (Affine.invert). Every screen pixel gets
 * exactly one color.
 *
 * That point in the image generally falls between image pixels;
 * choosing which color to take is called "filtering" (see
 * [sample_nearest], [sample_bilinear]).
 *
 * Here is where it stands. It draws the pictures of lib_playground's
 * games, through its software platform (Shape_render_software), such
 * as a sprite turned and scaled at each frame. A picture in a PDF page
 * is put on the paper the same way, by the inverse of its transform
 * (Pdf_canvas.image, with its own loop). The word's first sense, a
 * rectangle copied as it is, is the one operation of the draw device in
 * ix (Draw.mli tells bitblt's story and what replaced its boolean
 * functions).
 *
 * terminology:
 * Blit, sprite, texture. A blit is the copy; the Blit was also a
 * terminal of Bell Labs named after it (Display.mli). A sprite was at
 * first a small picture that the video hardware laid over the screen
 * by itself, with no copy at all (on the home computers and the game
 * consoles of around 1980). When memory and processors allowed it, it
 * became a picture blitted at each frame, and kept the name. A texture
 * is the same picture seen in three dimensions: it is drawn on a
 * triangle of a surface, which is this module's inverse mapping with
 * one more division, for the perspective.
 *
 * References:
 * - Paul S. Heckbert, "Fundamentals of Texture Mapping and Image
 *   Warping", Master's thesis, UC Berkeley, 1989 (forward vs inverse
 *   mapping, filtering).
 * - Edwin Catmull, "A Subdivision Algorithm for Computer Display of
 *   Curved Surfaces", PhD thesis, University of Utah, 1974 (the first
 *   texture mapping: an image drawn onto surfaces).
 * - Adele Goldberg, David Robson, "Smalltalk-80: The Language and its
 *   Implementation", Addison-Wesley, 1983 (BitBlt).
 *)
(* ix: the author's playground's libs/graphics/core/Blit.mli; here an image is an Rgba_image whose pixels are a Bytes, where it was a record of its own over a Bigarray (docs/plans/done/plan_pdf.md) *)

(* An image: width x height pixels, row by row from the top, 4 bytes per
 * pixel, red, green, blue, alpha (0 = transparent, 255 = opaque, not
 * premultiplied). It is the layout of Rgba_image.t, so images loaded by
 * Image_file.decode can be used as they are. *)
type image = Rgba_image.t

(* Colors with their alpha, from 0. to 1. *)
type color = { rgb : int; a : float }

(* [sample_nearest image (u, v)] is the color of the image pixel
 * containing the point (u, v), in image pixel coordinates (pixel (i, j)
 * is the square from (i, j) to (i+1, j+1)). It is the simplest filter,
 * and the blockiest: when the image is enlarged, each image pixel
 * becomes a visible square, which is the look of pixel art. *)
val sample_nearest : image -> float * float -> color

(* [sample_bilinear image (u, v)] is a mix of the 4 image pixels whose
 * centers surround (u, v), each weighted by how close it is, first
 * along x, then along y (hence "bi"-linear). For example, at the point
 * marked *, which is 30% of the way from the centers of A and C to
 * those of B and D, and 50% of the way from A and B to C and D:
 *
 *    A-----*--------B        top:    70% A + 30% B
 *    |     |        |
 *    |     *        |        result: 50% top + 50% bottom
 *    |     |        |
 *    C-----*--------D        bottom: 70% C + 30% D
 *
 * When enlarged, the image looks smooth (blurry for pixel art) instead
 * of blocky. At the image's borders, the missing neighbors are replaced
 * by the nearest border pixels. *)
val sample_bilinear : image -> float * float -> color

(* Which of the two samplers above to use *)
type filter = Nearest | Bilinear

(* [draw fb image m ~filter ~alpha] draws [image], with [m] mapping image
 * pixel coordinates to framebuffer pixel coordinates, taking colors
 * with [filter], and fading the result by [alpha]. A framebuffer pixel
 * is covered if its center comes from inside the image.
 *
 * There are two implementations, switched by Opti.enabled: the simple
 * one (a matrix product for each pixel, then [sample_nearest] or
 * [sample_bilinear]), and an optimized one that computes the same
 * pixels (with forward differencing and the samplers inlined; see
 * Blit.ml and notes_opti.md). With the optimized one, an image drawn as
 * it is (nearest, neither scaled nor turned, moved by whole pixels) is
 * also copied a row at a time, with no float. *)
val draw : Framebuffer.t -> image -> Affine.t -> filter:filter -> alpha:float -> unit

(* [resized image ~width ~height] returns the picture at that size, each
 * pixel computed from its four neighbours as [draw]'s Bilinear does,
 * but in whole numbers. Its colours are within a step or two of
 * [draw]'s, it gives the same bytes with both compilers, and it is many
 * times faster. It is for what is drawn again and again, such as a
 * film's frames, which are then drawn as they are. *)
val resized : image -> width:int -> height:int -> image
