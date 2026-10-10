(* Drawing line segments, 1 pixel wide: which pixels best approximate a
 * straight line between two points, on a grid where you can only light
 * whole pixels?
 *
 * Three algorithms, each told at its function below with an example
 * worked out by hand, and put together by [draw] and [draw_aa]:
 *
 *     two points, floats
 *          |
 *        [clip]         Cohen and Sutherland, 1967: the part of the
 *          |            segment that is on the screen, or none
 *          v
 *     [bresenham]       1965: a pixel a column, chosen by integer
 *      or [wu]          additions alone: a staircase
 *          |            1991: two pixels a column, which share the
 *          v            line's ink by how near each is: smooth
 *     Framebuffer.plot
 *
 * Where it stands: what lib_playground's software platform draws a
 * thin line with (Shape_render_software). A line with a width is not
 * drawn here: it is an area, made a polygon and filled (Stroke,
 * Fill). The draw device's lines (Draw.line) are found in the kernel
 * by the same stepping (mini-9pi's Memshape).
 *
 * cs-history:
 * Jack Bresenham wrote his at IBM in 1962, for a pen plotter whose
 * two motors could only step to one of the eight neighbours of where
 * the pen was, driven by a computer on which a multiplication was
 * slow and a fraction was not a thing a machine had. The plotter is
 * gone and the algorithm is in every graphics book: the grid of a
 * screen asks the same question.
 *
 * design:
 * Do not compute, update. The line's height at each column is a
 * multiplication and a division; the difference between two columns
 * is a constant, so an addition does. The same idea is in Circle
 * (the midpoint's test, updated), in Fill (an edge's crossing moves
 * by a constant from a row to the next) and in Blit (the place in
 * the picture of a pixel of the screen, from its neighbour's): what
 * the books call a digital differential analyzer, after a machine
 * that integrated by adding.
 *
 * modern:
 * A graphics card has no line of this kind: it fills triangles, and
 * a line is a thin rectangle, two of them, its edges smoothed by how
 * much of each pixel is covered. That is Stroke and Fill.polygons_aa
 * here; [wu] is the same result for a width of one pixel at a
 * fraction of the work. *)
(* ix: the author's playground's libs/graphics/2d/Line.mli (docs/plans/plan_playground.md) *)

(* [bresenham fb (x0, y0) (x1, y1) ~rgb ~alpha] lights the pixels of
 * the line from pixel (x0, y0) to pixel (x1, y1), both included, using
 * only integer additions and comparisons: Bresenham's algorithm.
 *
 * Take a line that goes more right than up or down, e.g. from (0, 0)
 * to (8, 3). Going right one pixel at a time, x = 0, 1, ..., 8, the
 * only question for each x is: same row as before, or the next one?
 * The exact line is at height 3/8 * x, so Bresenham keeps the "error",
 * how far the exact line is above the center of the current row, and
 * moves to the next row when it's more than half a pixel away. To stay
 * with integers, everything is multiplied by 2 * dx = 16 (dx = 8,
 * dy = 3): the error grows by 2 * dy = 6 at each step, and moving down
 * a row (that is, y + 1) takes 2 * dx = 16 away from it; "more than half a
 * pixel" is "error > dx = 8".
 *
 *   x   error+6   > 8?   y   (then error)
 *   0      -       -     0       0
 *   1      6      no     0       6
 *   2     12      yes    1      -4
 *   3      2      no     1       2
 *   4      8      no     1       8
 *   5     14      yes    2      -2
 *   6      4      no     2       4
 *   7     10      yes    3      -6
 *   8      0      no     3       0
 *
 *        x: 0 1 2 3 4 5 6 7 8
 *   y = 0   # #                      the exact line from the
 *   y = 1       # # #                center of (0, 0) to the
 *   y = 2             # #            center of (8, 3) passes
 *   y = 3                 # #        within half a pixel of
 *                                    every lit pixel's center
 *
 * (At x = 4 the exact line is at height 1.5, exactly between rows 1
 * and 2: a tie, which "> 8" rather than ">= 8" resolves by staying.)
 *
 * Lines that go more up or down than right are the same with the roles
 * of x and y swapped, and lines going left or up the same with -1 steps
 * instead of +1.
 *
 * Pixels outside the framebuffer are skipped, but still visited (see
 * [clip] for why that matters, and [draw]).
 *
 * Reference: Jack E. Bresenham, "Algorithm for computer control of a
 * digital plotter", IBM Systems Journal 4(1):25-30, 1965 (for a pen
 * plotter, whose motors could only step to neighboring grid points --
 * the same problem as lighting pixels). *)
val bresenham :
  Framebuffer.t -> int * int -> int * int -> rgb:int -> alpha:float -> unit

(* [clip ~width ~height p0 p1] is the part of the segment from p0 to p1
 * inside the rectangle [0, width] x [0, height], or None if there is
 * none. Without it, a line from (-1000000, 0) to (500, 500) would
 * visit a million invisible pixels before reaching the screen.
 *
 * The Cohen-Sutherland algorithm: the lines x = 0, x = width, y = 0,
 * y = height cut the plane into 9 regions, and each endpoint gets a
 * 4-bit code saying on which side of each line it is (1 = left,
 * 2 = right, 4 = above, 8 = below; y going down):
 *
 *          left       inside      right
 *        +----------+----------+----------+
 *  above |   0101   |   0100   |   0110   |
 *        +----------+==========+----------+
 *        |   0001   || 0000   ||   0010   |
 *        +----------+==========+----------+
 *  below |   1001   |   1000   |   1010   |
 *        +----------+----------+----------+
 *
 * - both codes 0000: the whole segment is inside, keep it;
 * - codes with a common 1 bit (code0 land code1 <> 0): both ends are
 *   beyond the same line, e.g. both above, so the segment can't cross
 *   the rectangle: drop it;
 * - otherwise, cut the segment where it crosses one of the lines an
 *   outside endpoint is beyond, replace that endpoint by the crossing
 *   point, and start again.
 *
 * Reference: Danny Cohen and Ivan Sutherland, 1967 (unpublished; first
 * described in William M. Newman and Robert F. Sproull, "Principles of
 * Interactive Computer Graphics", McGraw-Hill, 1973). *)
val clip :
  width:float -> height:float -> float * float -> float * float ->
  ((float * float) * (float * float)) option

(* [draw fb p0 p1 ~rgb ~alpha]: the line between two points in pixel
 * coordinates (x right, y down): [clip] to the framebuffer, then
 * [bresenham] between the pixels containing the two ends *)
val draw : Framebuffer.t -> float * float -> float * float -> rgb:int -> alpha:float -> unit

(* [wu fb p0 p1 ~rgb ~alpha]: an antialiased line, Xiaolin Wu's way.
 * Like Bresenham, one column at a time (for a mostly horizontal line),
 * but instead of choosing *one* pixel per column, light the two pixels
 * the exact line passes between, sharing the intensity by distance:
 * the closer pixel gets more. With pixel centers at integer
 * coordinates here (pixel (x, y)'s center, as for Bresenham), the line
 * from (0, 1) to (4, 3), whose height goes up by 0.5 per column:
 *
 *        x:  0    1    2    3    4
 *   y = 1   1.0  0.5                   at x = 1 the line is at 1.5,
 *   y = 2        0.5  1.0  0.5         half way: 0.5 and 0.5; at
 *   y = 3                  0.5  1.0    x = 2 it's exactly on row 2
 *
 * The two intensities always add up to 1, so the line looks equally
 * bright everywhere, instead of Bresenham's staircase. (Simplified: Wu's
 * paper also weighs the two end pixels by how much of them the line
 * covers.)
 *
 * Reference: Xiaolin Wu, "An efficient antialiasing technique",
 * SIGGRAPH '91 (Computer Graphics 25(4):143-152). *)
val wu : Framebuffer.t -> float * float -> float * float -> rgb:int -> alpha:float -> unit

(* [draw_aa]: [draw] with [wu] instead of [bresenham] *)
val draw_aa : Framebuffer.t -> float * float -> float * float -> rgb:int -> alpha:float -> unit
