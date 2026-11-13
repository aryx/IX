(* Playground shapes as a PDF's drawing operators. What
 * Shape_render_software makes pixels of is written here as the paths
 * themselves, so that a page of a file is sharp at any size and can be
 * printed.
 *
 * It is the same pipeline without its last step: a shape's own
 * transform is applied, then the one given, and the points that come
 * out are written; no pixel is decided here. The shapes become:
 * - a rectangle, an n-gon or a polygon: a filled path;
 * - a circle or an oval: four curves;
 * - words: Hershey's strokes, stroked by a round pen as wide as the
 *   screen's (the letters are drawn, they are not text, so nobody can
 *   select them);
 * - a Bitmap: its pixels, kept in the file;
 * - an Image, which is a file's name: its box, in grey, as on the
 *   screen;
 * - a shape's alpha: an opacity. A group's alpha is not looked at, as
 *   on the screen.
 *
 * Playground's y goes up, as a PDF's does, so a page is the shapes
 * moved from the centre to the bottom left corner, and nothing more. *)

(* [shapes file c m shapes] adds the shapes' operators to [c], where
 * [m] takes Playground's coordinates to the content's. The graphics
 * state is left as it was. *)
val shapes : Pdf_write.t -> Pdf_write.content -> Affine.t -> Playground.shape list -> unit

(* [page file ~width ~height shapes] adds a page of that size, where a
 * Playground unit is a point and (0, 0) is at its centre: it shows
 * what a window of that size shows *)
val page : Pdf_write.t -> width:float -> height:float -> Playground.shape list -> unit
