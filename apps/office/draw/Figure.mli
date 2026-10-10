(* One object of a drawing: a line, a rectangle, an oval, a piece of
 * text -- or a group of them, which is an object too.
 *
 * This is what separates a *drawing* program from a paint program
 * (appkits/paint): MacPaint's rectangle is gone once it is drawn, only
 * the dots it left remain; MacDraw's (1984) is still a rectangle,
 * which can be clicked, moved, resized, filled differently, sent
 * behind another. Bitmap against objects is still the difference
 * between Photoshop and Illustrator.
 *
 * Coordinates are the playground's: y up. A box is two corners,
 * always in order (x0 <= x1, y0 <= y1). Three ideas, one per group of
 * functions below:
 *
 * - **Hit testing** answers "did this click land on me?", and its
 *   subtlety is MacDraw's own: a *filled* shape is hit anywhere inside
 *   it, a *hollow* one only near its outline -- a click in the middle
 *   of an unfilled rectangle goes through to whatever is behind it,
 *   because nothing of the rectangle is there.
 *
 * - **Resizing is an affine map**: a figure is fitted to a new box by
 *   mapping its old bounds onto the new ones,
 *
 *     x' = nx0 + (x - x0) * (nx1 - nx0) / (x1 - x0)      (and y alike)
 *
 *   applied to every point it has. So a group, resized, scales
 *   everything in it, however deep -- the transform goes down the tree.
 *   (Pen widths and text sizes are not scaled, as in MacDraw.)
 *
 * - **Handles**: the eight squares round a selected figure's bounds
 *   (four corners, four sides), or a line's two ends; dragging one
 *   moves that corner, side or end, the opposite one staying put.
 *
 * The map on numbers: a group of a square and its diagonal, bounds
 * (0, 0) to (10, 10), fitted to a box twice as wide and half as tall,
 * (0, 0) to (20, 5):
 *
 *   the square's corner (10, 10)  ->  (20, 5)
 *   the diagonal's middle (5, 5)  ->  x' = 0 + (5 - 0) * 20 / 10 = 10
 *                                     y' = 0 + (5 - 0) *  5 / 10 = 2.5
 *
 * [fit] maps the points of everything in the group by the group's
 * bounds, not each figure by its own, which is what keeps them
 * together. A box of no width has nothing to scale by (a vertical
 * line's): its points all go to the new left edge.
 *
 * Where it stands. Drawing is a list of these with ids; Part_drawing
 * is the editor (its arrow, its handles, its menu), a part of any
 * document; Figure_shapes makes one Playground shapes. Nothing here
 * draws.
 *
 * design:
 * A figure is data, a variant, where a part of a document
 * (Component) is a record of functions, and the two modules are the
 * two answers to one question. Data can be compared (did the drag
 * change anything?), written by Marshal as it is (Part_drawing's
 * save) and matched by any new function, [restyle] added without
 * touching the rest; but a new kind of figure means a new case in
 * every function here. Functions are the reverse: a new kind of part
 * touches no code but its own, and nothing can be asked of a part
 * that its record did not foresee. Which one is right depends on
 * which grows, the kinds or the questions (Philip Wadler named it
 * the expression problem, 1998).
 *
 * cs-history:
 * The picture as objects is older than the picture as dots. Ivan
 * Sutherland's Sketchpad (MIT, 1963) drew lines and arcs with a
 * light pen on a display that redrew them from a list, kept them as
 * objects with constraints between them, and had copies that
 * followed their master. MacDraw (Apple, 1984, Mark Cutter's, after
 * his LisaDraw: from memory) is that idea with a mouse, handles, and
 * the Macintosh's menus.
 *
 * modern:
 * The type below, shapes and groups of shapes with styles, is every
 * vector format's: PostScript, PDF and SVG, whose g element is
 * [Group] (Svg, in lib_graphics, reads one). Playground's own shape
 * is the same tree too, made to be drawn; this one is made to be
 * edited, which is why a rectangle keeps its two corners, for the
 * handles, and not a centre and a turn.
 *
 * References: Ivan Sutherland, "Sketchpad: A Man-Machine Graphical
 * Communication System" (MIT, 1963). The playground's appkits/draw
 * and its TinyMacDraw, the program this was written for. *)

(*****************************************************************************)
(* {1 Figures and their boxes} *)
(*****************************************************************************)

type point = float * float
type box = { x0 : float; y0 : float; x1 : float; y1 : float }

(* the box with two opposite corners, whichever two *)
val box : point -> point -> box

(* [fill]: a grey from 0 (black) to 1 (white), or None for hollow;
 * [pen]: the outline's width *)
type style = { fill : float option; pen : float }

type t =
  | Line of point * point * style
  | Rect of box * style
  | Oval of box * style
  | Text of box * string * float (* its box, the text, its size *)
  | Group of t list

val bounds : t -> box

(* the box round two boxes *)
val union : box -> box -> box

(*****************************************************************************)
(* {1 Hit testing} *)
(*****************************************************************************)

(* [hit ~tolerance figure point]: whether the point is on the figure --
 * inside if it is filled (text always is), within [tolerance] of its
 * outline if it is hollow, within [tolerance] of a line *)
val hit : tolerance:float -> t -> point -> bool

(*****************************************************************************)
(* {1 Moving and resizing} *)
(*****************************************************************************)

val translate : float -> float -> t -> t

(* [fit box figure]: the figure resized so that its bounds are [box] *)
val fit : box -> t -> t

(*****************************************************************************)
(* {1 Handles} *)
(*****************************************************************************)

(* the handles, in order: a line's two ends; else the corners from the
 * top-left clockwise, then the sides top, right, bottom, left *)
val handles : t -> point list

(* [drag_handle figure i point]: handle [i] moved to [point]; a side
 * dragged past its opposite one makes the box the other way round (it
 * is not mirrored: the corners are sorted again) *)
val drag_handle : t -> int -> point -> t

(*****************************************************************************)
(* {1 Restyling} *)
(*****************************************************************************)

(* every style in it changed, a group's children included *)
val restyle : (style -> style) -> t -> t
