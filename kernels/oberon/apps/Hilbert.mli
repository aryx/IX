(* Hilbert's curve, in a viewer (Oberon's Hilbert): a program of
 * others, with a frame of its own that draws itself whenever its
 * rectangle changes. Hilbert.Draw opens one.
 *
 * The curve of order i is four curves of order i - 1, each turned
 * its own way, joined by three strokes; four procedures, one an
 * orientation, call each other (ha: hd, west, ha, south, ha, east,
 * hb). Order 1, where the smaller curves are nothing, is the three
 * strokes, and order 2 has that cup four times:
 *
 *     +---o           +---o   +---+
 *     |               |       |   |
 *     +---            +---+   +   +---
 *                         |           |
 *                     +---+   +   +---+
 *                     |       |   |
 *                     +---    +---+
 *
 * At the limit the line passes through every point of the square.
 * The frame shows the orders 1 to k one over the other, k as large
 * as the frame allows.
 *
 * cs-history:
 * David Hilbert's curve is of 1891, a year after Peano's: a line
 * that fills a square, which was thought impossible. The program is
 * Wirth's example of recursion that cannot be turned into a loop by
 * hand, in "Algorithms + Data Structures = Programs" (1976), with
 * Sierpinski's curve after it: both came into the Oberon system as
 * the first programs a reader would try. *)
val draw : unit -> unit
