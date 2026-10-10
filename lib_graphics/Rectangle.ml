(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A rectangle of the screen: its top left corner, and the point just
 * past its bottom right one (Plan 9's Rectangle: max is not inside;
 * xix's lib_graphics/geometry). No Rectangle.mli: a type and its
 * arithmetic.
 *
 * A point is not a pixel: it is a corner of the grid between the
 * pixels, and a pixel is named by its top left corner. A rectangle
 * is then the pixels between four lines of the grid:
 *
 *        0   1   2   3   4
 *      0 +---+---+---+---+       v 1 1 3 2: min (1, 1), max (3, 2)
 *        |   |   |   |   |       the pixels (1, 1) and (2, 1): the
 *      1 +---+===+===+---+       columns 1 and 2, the row 1
 *        |   |###|###|   |
 *      2 +---+===+===+---+       dx = 3 - 1 = 2, dy = 2 - 1 = 1
 *        |   |   |   |   |
 *      3 +---+---+---+---+
 *
 * design:
 * Half-open, as an array's slice from i to j without j. The width is
 * a subtraction with no + 1; two rectangles side by side share a
 * coordinate and no pixel (v 0 0 3 2 and v 3 0 5 2 tile, neither
 * drawn twice at column 3 nor a gap); min = max is the empty
 * rectangle; and a rectangle scaled by 2 is its numbers doubled.
 * With both corners inside, each of these is off by one somewhere,
 * and a line of pixels drawn twice shows as soon as the drawing is
 * not opaque. Dijkstra's note of 1982 argues it for ranges of
 * integers; the Blit's graphics and Plan 9's have it for the plane,
 * and so do PostScript's coordinates and every modern canvas.
 *
 * References: Edsger Dijkstra, "Why numbering should start at zero"
 * (EWD831, 1982); Rob Pike, Leo Guibas and Dan Ingalls, "Bitmap
 * Graphics" (SIGGRAPH 1984 course notes), points
 * between the pixels. *)

type t = { min : Point.t; max : Point.t }

let v x0 y0 x1 y1 = { min = Point.v x0 y0; max = Point.v x1 y1 }
let dx r = r.max.x - r.min.x
let dy r = r.max.y - r.min.y
(* moved by a point; shrunk by n on each side (grown, when negative) *)
let add r (p : Point.t) = { min = Point.add r.min p; max = Point.add r.max p }
let inset r n = v (r.min.x + n) (r.min.y + n) (r.max.x - n) (r.max.y - n)
let contains r (p : Point.t) = p.x >= r.min.x && p.x < r.max.x && p.y >= r.min.y && p.y < r.max.y
