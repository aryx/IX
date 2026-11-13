(* Lines, polygons, ellipses and arcs (memdraw's memline, mempoly,
 * memfillpoly, memellipse and memarc), in simple forms. This file
 * decides which pixels a shape has, and each row's run of them is drawn
 * from src by [draw] with op. The source point sp is aligned with the
 * shape's reference point: a line's p0, a polygon's first vertex, or an
 * ellipse's centre. The pixels are not exactly memdraw's (rio does not
 * draw these shapes), and the ends memdraw draws as arrows are square
 * ends here.
 *
 * A shape is turned into horizontal runs of pixels, and each run is
 * drawn as a one-row draw. So every shape is clipped, tiled, masked
 * and composed by the one operation that everything else uses
 * (Memdraw), and this file decides only which pixels to draw.
 *
 * cs-history:
 * A thin line is drawn by Jack Bresenham's algorithm (IBM, 1962, made
 * for a pen plotter). It steps along the longer axis and keeps in one
 * integer how far the true line has drifted from the pixels chosen,
 * stepping along the other axis when the drift passes a half. It uses
 * no multiplication and no fraction, because it was made for a machine
 * that had neither to spare, and it is still how a line is drawn. *)

type drawfn = Memimage.t -> Memimage.rect -> Memimage.t -> int * int -> Memimage.t -> int * int -> int -> unit

(* an ink is a source, its point, and the operator *)
type ink = Memimage.t * (int * int) * int

(* [line draw dst p0 p1 (end0, end1, radius) ink] draws a line
 * 1+2*radius wide. Each end is a disc (Enddisc, 1) or square. *)
val line : drawfn -> Memimage.t -> int * int -> int * int -> int * int * int -> ink -> unit

(* [poly ... pts (end0, end1, radius) ink] draws the lines between the
 * points *)
val poly : drawfn -> Memimage.t -> (int * int) list -> int * int * int -> ink -> unit

(* [fillpoly ... pts wind src sp op] fills the polygon, by the non-zero
 * rule when wind is ~0, and by the even-odd rule otherwise *)
val fillpoly : drawfn -> Memimage.t -> (int * int) list -> int -> Memimage.t -> int * int -> int -> unit

(* [ellipse ... c (a, b, thick) ink] draws an ellipse, filled when
 * thick < 0. [arc] draws only its part from alpha degrees through phi
 * degrees more. *)
val ellipse : drawfn -> Memimage.t -> int * int -> int * int * int -> ink -> unit
val arc : drawfn -> Memimage.t -> int * int -> int * int * int -> ink -> int * int -> unit
