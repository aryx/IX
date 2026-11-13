(* TinyOffice's drawing. This module reads a drawing's data, draws its
 * shapes, and lets the mouse and the keys make them.
 *
 * A drawing's data has one line per shape, at its place in the
 * drawing's box:
 *
 *     box 10 10 80 30 cpu              +--------+
 *     arrow 90 25 160 60               |  cpu   |----+
 *     text 20 70 a note                +--------+    |
 *                                                    v
 *                                       a note
 *
 * There are three kinds of shapes: a box with its label; an arrow,
 * which goes across then up or down, like a connector in a block
 * diagram (the shapes can only draw rectangles, and a slanted line
 * would need a new kind); and words. The left button drags out a box or
 * an arrow, or places a text. What is typed becomes the label of the
 * last shape.
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

(* [draw_stroke office tool (x0, y0, x1, y1)] adds the shape made by a
 * stroke to the selected drawing. A box or an arrow that is too small
 * counts as a click, not a shape. *)
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
