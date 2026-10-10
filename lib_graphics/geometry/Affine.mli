(* 2D affine transformations: moves (translations), rotations, scalings,
 * and any combination of them.
 *
 * Every transformation here maps a point (x, y) to
 *
 *   x' = a*x + c*y + tx
 *   y' = b*x + d*y + ty
 *
 * i.e. a 2x2 matrix [a c; b d] (which rotates/scales/flips) followed by
 * a translation (tx, ty). Written as a 3x3 matrix acting on (x, y, 1),
 * a trick called "homogeneous coordinates", the translation becomes
 * part of the matrix too:
 *
 *   | x' |   | a  c  tx |   | x |
 *   | y' | = | b  d  ty | * | y |
 *   | 1  |   | 0  0  1  |   | 1 |
 *
 * so that *every* transformation, translations included, is a matrix,
 * and doing one transformation after another is just multiplying their
 * matrices ([compose]). That's what makes a Playground [group] cheap:
 * moving a group of 100 shapes multiplies one matrix, not 100 shapes.
 *
 * Where it stands in ix: the six numbers are the ones the drawing
 * formats write, in this order. PostScript's matrix, PDF's operator
 * cm (Pdf_render: "200 0 0 150 50 400 cm" is a b c d tx ty, a
 * picture's unit square made 200 by 150 at (50, 400)), SVG's
 * transform="matrix(a b c d e f)" (Svg) and the web's canvas all
 * took PostScript's, so a file's transform is read into a [t] with
 * no arithmetic. The stack of them is the format's too: PDF's q and
 * Q, SVG's nested elements and a playground's groups each save a
 * matrix, compose one more, and take the saved one back. Blit and
 * Pdf_canvas use [invert], to go from a pixel of the screen back to
 * the picture.
 *
 * design:
 * Why affine and no more. These six numbers keep lines straight and
 * parallels parallel, which is all a page or a sprite needs. The
 * bottom row 0 0 1 is what is given up: with numbers there, far
 * things get smaller (a projective transform, the perspective of
 * three dimensions), parallels meet, and every point costs a
 * division. PostScript chose not to have it, and paper has none.
 *
 * References:
 * - Lawrence G. Roberts, "Homogeneous Matrix Representation and
 *   Manipulation of N-Dimensional Constructs", MIT Lincoln Laboratory
 *   MS-1405, 1965 (homogeneous coordinates for computer graphics).
 * - Ivan E. Sutherland, "Sketchpad: A Man-Machine Graphical
 *   Communication System", MIT PhD thesis, 1963 (drawings made of
 *   transformed instances of other drawings -- the ancestor of
 *   Playground's [group]).
 * - Foley, van Dam, Feiner, Hughes, "Computer Graphics: Principles and
 *   Practice", 2nd ed., 1990, chapter 5 (the textbook treatment).
 *)
(* ix: the author's playground's libs/graphics/2d/geometry/Affine.mli (docs/plans/plan_playground.md) *)

type t = { a : float; b : float; c : float; d : float; tx : float; ty : float }

(* (x, y) -> (x, y) *)
val identity : t

(* [translate dx dy]: (x, y) -> (x + dx, y + dy) *)
val translate : float -> float -> t

(* [rotate radians]: counterclockwise around (0, 0), in a y-up world
 * like Elm's; e.g. rotate (pi/2) maps (1, 0) to (0, 1) *)
val rotate : float -> t

(* [scale sx sy]: (x, y) -> (sx * x, sy * y); e.g. scale 1. (-1.)
 * flips upside down *)
val scale : float -> float -> t

(* [compose m n] is "n, then m", like function composition (m o n):
 *   apply (compose m n) p = apply m (apply n p)
 * The order matters: rotating then moving is not moving then rotating.
 * For example, for the point (1, 0):
 *   compose (translate 10. 0.) (rotate (pi/2)):  (1, 0) -> (0, 1) -> (10, 1)
 *   compose (rotate (pi/2)) (translate 10. 0.):  (1, 0) -> (11, 0) -> (0, 11)
 *)
val compose : t -> t -> t

val apply : t -> float * float -> float * float

(* [invert m] undoes [m]: apply (invert m) (apply m p) = p. E.g. the
 * inverse of "rotate a quarter turn, then move right by 10" is "move
 * left by 10, then rotate a quarter turn back". Used to go from the
 * screen back to an image's pixels (see Blit). The matrix must be
 * invertible: not squashing everything onto a line or a point (a scale
 * by 0), which Playground never does except with [scale 0.]. *)
val invert : t -> t
