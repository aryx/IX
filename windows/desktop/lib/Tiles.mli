(* Where Expose puts each window, without a screen: a grid on the area, a
 * cell a window, each window shrunk by a whole factor to fit its cell with
 * room for its name below.
 *
 *     +-----------+-----------+
 *     |  +-----+  | +-------+ |    the cells as square as the area allows:
 *     |  |  1  |  | |   2   | |    as many columns as the square root of
 *     |  +-----+  | +-------+ |    the windows, rounded up
 *     |   rc 3    |   files   |
 *     +-----------+-----------+
 *
 * A whole factor because the draw device's shrink takes one (Draw.shrink:
 * a pixel of the thumbnail for k by k of the window): a thumbnail is then
 * a little smaller than its cell, never stretched, never another shape. *)

(* [layout area sizes]: for each window's width and height, in order, its
 * cell, its thumbnail's rectangle, and k *)
val layout : Rectangle.t -> (int * int) list -> (Rectangle.t * Rectangle.t * int) list

(* the room below a thumbnail for its name *)
val label_h : int
