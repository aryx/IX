(* TinyOffice's drawing. This module reads a drawing's data, draws its
 * shapes, and lets the mouse and the keys make them.
 *
 * A drawing's data has one line per shape, at its place in the
 * drawing's box:
 *
 *     box 10 10 80 30 cpu              +--------+
 *     arrow 90 25 160 60               |  cpu   |\
 *     text 20 70 a note                +--------+ \
 *     oval 130 70 60 30 io                         \
 *                                       a note    ( io )
 *
 * There are four kinds of shapes: a box with its label; an arrow,
 * a straight line from its first point to its second, where its head
 * is (the line and the head are each one of the playground's
 * polygons); words; and an oval with its label, the ellipse in
 * its box. The left button drags out a box, an arrow or an oval, or
 * places a text. What is typed becomes the label of the last shape.
 *
 * cs-history:
 * pic (Brian Kernighan, 1982, a troff preprocessor) describes a
 * picture as lines of text, such as "box" and "arrow". Here the shapes
 * are drawn with the mouse, as in MacDraw, but stored as in pic.
 *)

(* The tools' names, indexed by the tool's number in a Sketch edit. *)
val tools : string list

(* The shapes in a drawing's data. Each shape is given as its kind, its
 * numbers and its label. *)
val figures : string -> (string * int list * string) list

(* [arrow_head x0 y0 x1 y1] is the three corners of the head of the
 * arrow from (x0, y0) to (x1, y1): its tip at (x1, y1), and the two
 * others 8 pixels back along the arrow, 4 on each side of it.
 * tiny-troff prints the same head. *)
val arrow_head : int -> int -> int -> int -> (int * int) list

(* [draw_stroke office tool (x0, y0, x1, y1)] adds the shape made by a
 * stroke to the selected drawing. A box, an oval or an arrow that is
 * too small counts as a click, not a shape. *)
val draw_stroke :
  Model.office -> int -> int * int * int * int -> unit

(* [sketch_key office tool key] handles a key in a drawing. Tab changes
 * the tool. A character is added to the last shape's label, and
 * Backspace removes one (a shape whose label becomes empty is removed).
 * C-g stops editing the drawing. *)
val sketch_key : Model.office -> int -> TinyLibPlayground.key -> unit

(* [drawing_view box tool stroke] draws the shapes, and draws the
 * stroke being made in blue. *)
val drawing_view :
  Model.obj -> int -> (int * int * int * int) option ->
  TinyLibPlayground.shape list
