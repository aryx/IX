(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A rectangle of the screen: its top left corner, and the point just
 * past its bottom right corner (Plan 9's Rectangle, where max is not
 * inside; xix's lib_graphics/geometry). There is no Rectangle.mli,
 * because this is only a type and its arithmetic.
 *
 * A point is not a pixel: it is a corner of the grid between the
 * pixels, and a pixel is named by its top left corner. A rectangle is
 * then the pixels between four lines of the grid:
 *
 *        0   1   2   3   4
 *      0 +---+---+---+---+       v 1 1 3 2 has min (1, 1), max (3, 2)
 *        |   |   |   |   |       and the pixels (1, 1) and (2, 1):
 *      1 +---+===+===+---+       the columns 1 and 2, of the row 1
 *        |   |###|###|   |
 *      2 +---+===+===+---+       dx = 3 - 1 = 2, dy = 2 - 1 = 1
 *        |   |   |   |   |
 *      3 +---+---+---+---+
 *
 * design:
 * The rectangle is half-open, as an array's slice from i to j without
 * j. The width is a subtraction with no + 1. Two rectangles side by
 * side share a coordinate and no pixel (v 0 0 3 2 and v 3 0 5 2 tile:
 * column 3 is neither drawn twice nor left as a gap). min = max is the
 * empty rectangle. And a rectangle scaled by 2 is its numbers doubled.
 * With both corners inside, each of these is off by one somewhere, and
 * a line of pixels drawn twice shows as soon as the drawing is not
 * opaque. Dijkstra's note of 1982 argues for it for ranges of integers;
 * the Blit's graphics and Plan 9's use it for the plane, and so do
 * PostScript's coordinates and every modern canvas.
 *
 * References: Edsger Dijkstra, "Why numbering should start at zero"
 * (EWD831, 1982); Rob Pike, Leo Guibas and Dan Ingalls, "Bitmap
 * Graphics" (SIGGRAPH 1984 course notes), on points between the
 * pixels. *)

type t = { min : Point.t; max : Point.t }

let v x0 y0 x1 y1 = { min = Point.v x0 y0; max = Point.v x1 y1 }
let dx r = r.max.x - r.min.x
let dy r = r.max.y - r.min.y
(* moved by a point; shrunk by n on each side (grown, when negative) *)
let add r (p : Point.t) = { min = Point.add r.min p; max = Point.add r.max p }
let inset r n = v (r.min.x + n) (r.min.y + n) (r.max.x - n) (r.max.y - n)
let contains r (p : Point.t) = p.x >= r.min.x && p.x < r.max.x && p.y >= r.min.y && p.y < r.max.y
