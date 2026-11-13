(* Browser_text: the letters of a page. It gives the width of a word in
 * a look, for the layout (Html_layout never sees a font), and the pen
 * that draws the word with Hershey's strokes (Stroke_text).
 *
 * Hershey has one face, so a fixed-width look (<tt>, <pre>, a text
 * field) is that face set on a grid of cells 0.6 em wide, with each
 * letter centred in its cell, as on a typewriter. Bold and italic are
 * done by the pen (Stroke_text.mli). The root's size is 16, as a
 * browser's text is 16 px. *)

(* the characters of a UTF-8 string, each as its own string *)
val characters : string -> string list

(* the root's look: its text is 16 high *)
val root_look : Looks.t

(* a look as Stroke_text's pen knows it *)
val style_of : Looks.t -> Style.t

(* the cell of a fixed-width character: 0.6 em *)
val cell_of : Looks.t -> float

(* the layout's metrics: Hershey's widths, or the cells of a fixed-width
 * look *)
val metrics : Html_layout.metrics

(* the last characters of [s] that fit in [n] cells *)
val tail : int -> string -> string

(* "<", ">" and "&" written as HTML's entities, for text put in a
 * page *)
val escape_html : string -> string
