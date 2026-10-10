(* The paint bucket: pour a pattern into the area around a dot, as far
 * as the dots of the same colour reach -- left, right, up and down, but
 * not diagonally, so that a line of dots touching only at their corners
 * still holds the paint in.
 *
 * It is done in two steps, and the order is the lesson. First find the
 * area -- a mask, a bitmap of its own with a 1 for every dot of it --
 * and only then paint the pattern through the mask. Painting as you go
 * is the obvious way and it does not finish: pour grey into white, and
 * the grey's own white dots look like area not yet painted, and the
 * fill goes round and round them. (QuickDraw's SeedFill computes exactly
 * that mask, and MacPaint painted through it.)
 *
 * Finding the area goes a row at a time, not a dot at a time: from a
 * seed, run left and right to the edges of its row, mark that span,
 * then look along the rows above and below the span for more of the
 * area, and push one seed per run found there. A span is marked in one
 * go, and each dot is looked at a few times, not once per neighbour --
 * Alvy Ray Smith's "Tint Fill" (SIGGRAPH 1979); Paul Heckbert's "A
 * Seed Fill Algorithm" (Graphics Gems, 1990) is the version everyone
 * copies.
 *
 *   ########       the seed * in the middle: row 2 is marked from the
 *   #......#       first wall to the other, then rows 1 and 3 are
 *   #...*..#       searched along that span -- one seed each -- and
 *   #......#       so on outwards
 *   ########
 *
 * The seeds wait on a stack, and that is the other reason for spans.
 * The fill everyone writes first is four lines, a function that
 * paints its dot and calls itself on the four neighbours: on
 * MacPaint's page it can be 414,720 calls deep, one for each dot of
 * a white page. Here the stack holds a seed for each run still to
 * look at, a few for a plain area.
 *
 * Where it stands. Part_picture's Fill tool is [fill] at the dot
 * clicked, inside Bitmap.change. The platforms fill too, and it is
 * another problem: Fill (lib_graphics) is given a polygon's corners
 * and finds the dots inside by geometry, row by row; this is given
 * one dot and finds the area from the picture itself, knowing no
 * shape. A paint program has only the second, having kept no shapes.
 *
 * terminology:
 * Left, right, up and down is 4-connected; with the diagonals too,
 * 8-connected. They go by pairs: if the area is 4-connected, the
 * line that stops it may be 8-connected (dots touching by a corner),
 * as the first paragraph says; fill an 8-connected area and that
 * line leaks. The name outside paint programs is flood fill.
 *
 * modern:
 * The mask is worth more than the fill. Computed and kept, [area] is
 * a selection: the magic wand of a picture editor is this function
 * with "the same colour" made "a colour near enough", and the lasso
 * is the mask of what a fill from outside the loop did not reach.
 *
 * References: Alvy Ray Smith, "Tint Fill" (SIGGRAPH 1979). Paul
 * Heckbert, "A Seed Fill Algorithm", in Graphics Gems (1990). "Inside
 * Macintosh", QuickDraw's SeedFill and CalcMask.
 *)

(* [area b x y]: the mask of the area dot ([x], [y]) is in; all white
 * if the dot is outside the picture *)
val area : Bitmap.t -> int -> int -> Bitmap.t

(* [fill b p x y]: the pattern poured in, in place *)
val fill : Bitmap.t -> Pattern.t -> int -> int -> unit
