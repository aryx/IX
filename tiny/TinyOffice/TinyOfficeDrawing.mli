(* TinyOffice's drawing: its data, the shapes it draws, how the mouse
 * and the keys make them.
 *
 * A drawing's data is a line a shape, at its place in the drawing's
 * box:
 *
 *     box 10 10 80 30 cpu              +--------+
 *     arrow 90 25 160 60               |  cpu   |----+
 *     text 20 70 a note                +--------+    |
 *                                                    v
 *                                       a note
 *
 * a box and its label; an arrow, across then up or down (a block
 * diagram's connector: what the shapes draw is rectangles, and a
 * slanted line would need another kind); words. The left button drags
 * a box or an arrow, or places a text; what is typed is the last
 * shape's label.
 *
 * cs-history:
 * pic (Brian Kernighan, 1982, a troff preprocessor) has a picture as
 * lines of text, "box", "arrow"; here they are drawn with the mouse,
 * as MacDraw's, and kept as pic's.
 *)

(* the tools, by their number in an edit's Sketch: a box, an arrow, a
 * text *)
val tools : string list

(* a drawing's shapes: their kind, their numbers, their label *)
val figures : string -> (string * int list * string) list

(* [draw_stroke office tool (x0, y0, x1, y1)]: the shape a stroke made,
 * added to the selected drawing; a box or an arrow too small is a
 * click, not a shape *)
val draw_stroke :
  TinyOfficeModel.office -> int -> int * int * int * int -> unit

(* [sketch_key office tool key]: Tab another tool; a character the last
 * shape's label longer; Backspace shorter, and an empty label's shape
 * removed; C-g the drawing left *)
val sketch_key : TinyOfficeModel.office -> int -> int -> unit

(* [drawing_view box tool stroke]: its shapes, and the stroke being
 * made, in blue *)
val drawing_view :
  TinyOfficeModel.obj -> int -> (int * int * int * int) option ->
  TinyLibPlayground.shape list
