(* Playground shapes as a PDF's drawing operators: what
 * Shape_render_software makes pixels of, written as the paths
 * themselves, so that a page of a file is sharp at any size and
 * prints.
 *
 * The same pipeline, less its last step: a shape's own transform,
 * then the one given, and the points that come out are written; no
 * pixel is decided here. A rectangle, an n-gon, a polygon: a path
 * filled. A circle, an oval: four curves. Words: Hershey's strokes,
 * stroked by a round pen of the width the screen's has (the letters
 * are drawn, they are not text: nobody selects them). A Bitmap: its
 * pixels, kept in the file. An Image, which is a file's name: its
 * box, grey, as the screen's. A shape's alpha: an opacity; a group's
 * is not looked at, as there.
 *
 * Playground's y goes up, as a PDF's: a page is the shapes moved
 * from the centre to the bottom left corner, and no more. *)

(* [shapes file c m shapes]: the shapes' operators added to [c], [m]
 * taking Playground's coordinates to the content's; the graphics
 * state is left as it was *)
val shapes : Pdf_write.t -> Pdf_write.content -> Affine.t -> Playground.shape list -> unit

(* [page file ~width ~height shapes]: a page of that size, a
 * Playground unit a point, (0, 0) at its centre: what a window of
 * that size shows *)
val page : Pdf_write.t -> width:float -> height:float -> Playground.shape list -> unit
