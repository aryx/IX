(* Pic: a picture read and drawn -- what is between .PS and .PE, pic's
 * language, the part of it that draws.
 *
 *   .PS
 *   A: box "readers"; arrow; B: box "Doc.t"
 *   arrow from B.s down 0.3
 *   ellipse "layout"
 *   .PE
 *
 *   +---------+     +-------+
 *   | readers |---->| Doc.t |          a picture is objects, each put
 *   +---------+     +-------+          where the one before ended and
 *                       |              in the way things are going
 *                       v              (right, to begin with); or at a
 *                    (layout)          place said: "at A.ne", "from
 *                                      B.s", "with .w at last box.e"
 *
 * The objects: box, circle, ellipse, line, arrow, arc, spline, move
 * (nothing drawn), a text alone, and a block of statements between
 * brackets, which is an object too, with the names in it its own
 * (Block.Inner.s). Of an object: its size (wid, ht, rad), its place
 * (at, with a corner), a line's points (from, to, up 0.5, then), an
 * arrow's heads (-> <- <->), invis, its texts and where each is
 * (ljust, above). A place: a name and a corner, the last box, a point
 * (x, y), a place and a move from it, a part of the way between two
 * (0.3 <A, B>). Variables (boxwid = 0.5, scale = 100) and arithmetic;
 * macros (define, in Pic_lexer).
 *
 * What comes out is lines and words, in inches from the picture's
 * lower left: a circle and a spline are the short lines that look
 * like them. Dashes and fills are not drawn (the line is solid, the
 * box empty), nor pic's programs run (for, if, sh).
 *
 * cs-history:
 * pic is Brian Kernighan's (Bell Labs, 1981), the third of troff's
 * preprocessors and the one that made "little languages" a phrase:
 * a picture described in words, in the document, by someone who
 * cannot draw, "box; arrow; box" being a picture already. Jon
 * Bentley's column of 1986 took its name from it. Graphviz's dot and
 * TikZ are its descendants in spirit: the first lays the boxes out
 * itself, the second gives TeX's users the same words. *)

(* [read load width words text]: a picture's text drawn; [width] is
 * what .PS says the picture's is, in inches (0: its own); [load] reads
 * a file that it copies; [words] makes of a string between quotes the
 * words in their fonts. Or why it is not understood: the words of it
 * read last, a name that is not there. *)
val read : (string -> string option) -> float -> (string -> Doc.inline list) -> string -> (Doc.picture, string) result
