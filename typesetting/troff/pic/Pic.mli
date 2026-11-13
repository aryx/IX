(* Pic reads a picture and draws it: what is between .PS and .PE, in
 * pic's language, the part of it that draws.
 *
 *   .PS
 *   A: box "readers"; arrow; B: box "Doc.t"
 *   arrow from B.s down 0.3
 *   ellipse "layout"
 *   .PE
 *
 *   +---------+     +-------+
 *   | readers |---->| Doc.t |          a picture is objects, each put
 *   +---------+     +-------+          where the one before ended, in
 *                       |              the direction things are going
 *                       v              (right, to begin with), or at a
 *                    (layout)          place that is given: "at A.ne",
 *                                      "from B.s", "with .w at last
 *                                      box.e"
 *
 * The objects are box, circle, ellipse, line, arrow, arc, spline, move
 * (nothing is drawn), a text alone, and a block of statements between
 * brackets. A block is an object too, and the names in it are its own
 * (Block.Inner.s). What can be said of an object:
 *   - its size (wid, ht, rad);
 *   - its place (at, with a corner);
 *   - a line's points (from, to, up 0.5, then);
 *   - an arrow's heads (-> <- <->);
 *   - invis;
 *   - its texts, and where each one is (ljust, above).
 * A place is a name and a corner, the last box, a point (x, y), a place
 * and a move from it, or a part of the way between two places (0.3
 * <A, B>). There are also variables (boxwid = 0.5, scale = 100) and
 * arithmetic, and macros (define, done in Pic_lexer).
 *
 * What comes out is lines and words, in inches from the picture's
 * lower left corner. A circle and a spline become short lines that
 * look like them. Dashes and fills are not drawn (the line is solid,
 * and the box empty), and pic's programs are not run (for, if, sh).
 *
 * cs-history:
 * Brian Kernighan wrote pic (Bell Labs, 1981), the third of troff's
 * preprocessors, and the one that made "little languages" a phrase. A
 * picture is described in words, inside the document, by someone who
 * cannot draw, and "box; arrow; box" is already a picture. Jon
 * Bentley's column of 1986 took its name from it. Graphviz's dot and
 * TikZ are its descendants in spirit: the first lays the boxes out
 * itself, and the second gives TeX's users the same words. *)

(* [read load width words text] draws a picture's text. [width] is the
 * picture's width as .PS gives it, in inches (0 for its own width).
 * [load] reads a file that the picture copies. [words] turns a string
 * between quotes into words in their fonts. When the text is not
 * understood, the result says why: the words read last, or a name
 * that is not there. *)
val read : (string -> string option) -> float -> (string -> Doc.inline list) -> string -> (Doc.picture, string) result
