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
 * A fifth tool, select, picks a shape made before: a click on it makes
 * it the drawing's last shape (shown in blue, and drawn over the
 * others), and a drag moves it too. A box or an oval dragged by its
 * bottom right corner (a small square when it is selected) is resized
 * instead, and an arrow dragged by one end has that end moved. When a
 * box, an oval or a text moves, each arrow's end that was on it moves
 * with it: the file does not say which box an arrow goes to, the
 * place of its ends does. So the selected shape is simply
 * the last one, which a label is typed in and which Backspace (once
 * its label is empty) or C-d removes; nothing else is kept about a
 * selection.
 *
 * cs-history:
 * pic (Brian Kernighan, 1982, a troff preprocessor) describes a
 * picture as lines of text, such as "box" and "arrow". Here the shapes
 * are drawn with the mouse, as in MacDraw, but stored as in pic.
 *)

(* The tools' names, indexed by the tool's number in a Sketch edit;
 * [select] is the number of the tool that picks a shape. *)
val tools : string list
val select : int

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
 * too small counts as a click, not a shape. With the select tool, the
 * shape under (x0, y0) becomes the last one, moved by the stroke (or
 * resized, or one of an arrow's ends moved, when the stroke began at
 * most 6 pixels from a corner or an end); of several shapes there, an
 * arrow is picked first, then the shape with the smallest box. *)
val draw_stroke :
  Model.office -> int -> int * int * int * int -> unit

(* [sketch_key office tool key] handles a key in a drawing. Tab changes
 * the tool. A character is added to the last shape's label, and
 * Backspace removes one (a shape whose label becomes empty is removed).
 * C-d removes the last shape. C-g stops editing the drawing. *)
val sketch_key : Model.office -> int -> TinyLibPlayground.key -> unit

(* [drawing_view box tool stroke] draws the shapes, and draws the
 * stroke being made in blue. With the select tool, the last shape is
 * blue, and the stroke is the picked shape where it would be moved. *)
val drawing_view :
  Model.obj -> int -> (int * int * int * int) option ->
  TinyLibPlayground.shape list
