(* Drawing (Plan 9's libdraw; xix's lib_graphics/draw): each function a
 * message of the draw device's, on a Display's images. *)

(* [draw dst r src mask p]: src through mask into dst's rectangle r,
 * Plan 9's one operation: src's point p (and mask's) goes to r's
 * corner. A colour as src fills r; a mask says where (none: all of r). *)
val draw : Display.image -> Rectangle.t -> Display.image -> Display.image option -> Point.t -> unit
(* the same, the mask's point said apart (a character in a font's image) *)
val draw_mask : Display.image -> Rectangle.t -> Display.image -> Point.t -> Display.image -> Point.t -> unit

(* a rectangle filled; its border, n pixels wide, inside it *)
val fill : Display.image -> Rectangle.t -> Display.image -> unit
val border : Display.image -> Rectangle.t -> int -> Display.image -> unit

(* [line dst p0 p1 thick src]: a line from p0 to p1, 1 + 2 * thick pixels wide *)
val line : Display.image -> Point.t -> Point.t -> int -> Display.image -> unit

(* [poly dst points thick src]: the lines from each point to the next,
 * 1 + 2 * thick pixels wide; [fillpoly]: what they enclose, the last
 * point joined to the first (a point is inside when the edges round it
 * do not cancel out: a shape that crosses itself is filled whole) *)
val poly : Display.image -> Point.t list -> int -> Display.image -> unit
val fillpoly : Display.image -> Point.t list -> Display.image -> unit

(* [ellipse dst c a b thick src]: the ellipse of centre c and half axes
 * a (across) and b (down), its line 1 + 2 * thick pixels wide;
 * [fillellipse]: its inside *)
val ellipse : Display.image -> Point.t -> int -> int -> int -> Display.image -> unit
val fillellipse : Display.image -> Point.t -> int -> int -> Display.image -> unit

