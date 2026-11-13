(* Where Expose puts each window, computed without a screen. The area is
 * cut into a grid with a cell for each window, and each window is shrunk
 * by a whole factor to fit its cell, with room for its name below.
 *
 *     +-----------+-----------+
 *     |  +-----+  | +-------+ |    the cells are as square as the area
 *     |  |  1  |  | |   2   | |    allows: as many columns as the
 *     |  +-----+  | +-------+ |    square root of the number of
 *     |   rc 3    |   files   |    windows, rounded up
 *     +-----------+-----------+
 *
 * The factor is a whole number because the draw device's shrink takes
 * one (Draw.shrink: a pixel of the thumbnail for k by k pixels of the
 * window). A thumbnail is then a little smaller than its cell, but it is
 * never stretched and never another shape. *)

(* [layout area sizes] gives, for each window's width and height, in
 * order, the window's cell, its thumbnail's rectangle, and k *)
val layout : Rectangle.t -> (int * int) list -> (Rectangle.t * Rectangle.t * int) list

(* the room below a thumbnail for its name *)
val label_h : int
