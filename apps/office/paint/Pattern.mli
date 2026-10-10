(* A pattern: 8 by 8 dots, repeated like tiles over the whole picture --
 * how a screen of black and white dots painted "grey", "bricks" and
 * "sky". It is 8 bytes, one per row, the leftmost dot highest, as
 * QuickDraw stored it:
 *
 *   grey    0xAA  #.#.#.#.        a checkerboard: from arm's length,
 *           0x55  .#.#.#.#        half black is grey
 *           0xAA  #.#.#.#.
 *           ...
 *
 * The tiles are laid from the picture's own (0, 0), not from where
 * the painting starts: dot (x, y) is painted with the pattern's dot
 * (x mod 8, y mod 8). So two areas painted separately in the same
 * pattern join without a seam -- the property every paint program
 * since has kept, and the reason a pattern is not an image.
 *
 * The palette below is MacPaint's in spirit (it had 38), not its
 * exact table.
 *
 * A pattern need not be a grey. The palette's bricks, and four tiles
 * of them side by side and one under the other, which is where the
 * wall appears:
 *
 *   0xFF  ########        ################
 *   0x80  #.......        #.......#.......
 *   0x80  #.......        #.......#.......
 *   0x80  #.......        #.......#.......
 *   0xFF  ########        ################
 *   0x08  ....#...        ....#.......#...
 *   0x08  ....#...        ....#.......#...
 *   0x08  ....#...        ....#.......#...
 *                         ################
 *                         #.......#.......    ...
 *
 * Where it stands. Paint.dot asks [black] for each dot it paints, and
 * that is the only use: a pattern is a colour, to the tools.
 * Part_picture's menu offers three of the palette (black, grey,
 * bricks).
 *
 * terminology:
 * Painting a grey with black dots is halftoning, the printers' word
 * (a newspaper photograph is dots of ink of several sizes), or
 * dithering. The checkerboard above is the simplest ordered dither:
 * a fixed tile of thresholds laid over the picture, a dot black
 * where the grey wanted is darker than its threshold (Bayer, 1973).
 * A pattern is that tile with the comparison already made, for one
 * grey.
 *
 * modern:
 * A screen has greys now, and a grey is a number in each dot. The
 * tile survived as decoration: a web page's background repeated
 * from its corner, a PDF's tiling pattern (which Pdf_render does
 * not draw yet), and both keep the rule above, tiles laid from the
 * page's origin and not from the shape's.
 *
 * References: "Inside Macintosh", volume I (1985), QuickDraw's
 * Pattern (from memory). B. E. Bayer, "An optimum method for
 * two-level rendition of continuous-tone pictures" (IEEE
 * International Conference on Communications, 1973). *)

type t = string (* 8 bytes, a row each *)

(* whether the pattern is black at a dot of the picture *)
val black : t -> int -> int -> bool

(* [make rows]: from 8 bytes, e.g. [make [| 0xAA; 0x55; ... |]] *)
val make : int array -> t

val solid : t
val white : t
val grey : t

(* the palette, in the order it is shown *)
val palette : t list
