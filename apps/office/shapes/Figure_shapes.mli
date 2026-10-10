(* A drawing's figures (appkits/draw) as Playground shapes, shared by
 * TinyMacDraw and the drawing part of compound documents
 * (Part_drawing): a fill as a grey, an outline as strokes -- thin
 * rectangles, turned -- and text through Stroke_text. The shapes are in
 * the drawing's own coordinates; a part fits them to its rectangle by
 * grouping and scaling them.
 *
 * (In ix: appkits/draw is Figure and Drawing, and Part_drawing is the
 * one caller; TinyMacDraw is the playground's.) This is the line
 * between the kit and the screen: Figure knows what a rectangle is
 * and how it is hit and resized, this module alone how it looks, and
 * a figure's fill being a grey and not a pattern is decided here,
 * since Playground fills with colours. *)

(* a grey, 0 black to 1 white *)
val grey : float -> Playground.color

(* [segment color width a b]: a stroke from a to b *)
val segment : Playground.color -> float -> Figure.point -> Figure.point -> Playground.shape

val figure : Figure.t -> Playground.shape list
