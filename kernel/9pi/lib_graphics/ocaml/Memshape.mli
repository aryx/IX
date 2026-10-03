(* Lines, polygons, ellipses and arcs (memdraw's memline, mempoly,
 * memfillpoly, memellipse, memarc), in simple forms: a shape's pixels
 * decided here, each row's run of them drawn from src (the source
 * point sp aligned with the shape's reference point: a line's p0, a
 * polygon's first vertex, an ellipse's centre) by [draw] with op. Not
 * memdraw's pixels exactly (rio does not draw these; its arrows are
 * square ends here). *)

type drawfn = Memimage.t -> Memimage.rect -> Memimage.t -> int * int -> Memimage.t -> int * int -> int -> unit

(* an ink: a source, its point, the operator *)
type ink = Memimage.t * (int * int) * int

(* [line draw dst p0 p1 (end0, end1, radius) ink]: 1+2*radius wide,
 * an end a disc (Enddisc, 1) or square *)
val line : drawfn -> Memimage.t -> int * int -> int * int -> int * int * int -> ink -> unit

(* [poly ... pts (end0, end1, radius) ink]: the lines between them *)
val poly : drawfn -> Memimage.t -> (int * int) list -> int * int * int -> ink -> unit

(* [fillpoly ... pts wind src sp op]: wind ~0 non-zero, else even-odd *)
val fillpoly : drawfn -> Memimage.t -> (int * int) list -> int -> Memimage.t -> int * int -> int -> unit

(* [ellipse ... c (a, b, thick) ink]: thick < 0 filled; [arc] its part
 * from alpha degrees through phi more *)
val ellipse : drawfn -> Memimage.t -> int * int -> int * int * int -> ink -> unit
val arc : drawfn -> Memimage.t -> int * int -> int * int * int -> ink -> int * int -> unit
