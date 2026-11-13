(* This module says what a widget is. A widget is four things, and
 * every toolkit ever written agrees on these even when it disagrees
 * about everything else (notes_gui.md section 2):
 *
 *   +-------------------+   a rectangle   (where it is)
 *   |      Save         |   a drawing     (paint, below)
 *   +-------------------+   a hit test    (is this point mine?)
 *                           some state    (pressed? focused?)
 *
 * The first three are here. The fourth is the whole argument between
 * the four architectures, and it lives in whoever keeps it: Immediate
 * keeps it in one table, a retained toolkit keeps it in the widget
 * objects, and MVU keeps it in the model.
 *
 * This module knows nothing of the playground: a widget draws itself
 * as [paint], a list of coloured rectangles and pieces of text, and
 * Gui.ml turns those into shapes. That is what lets the
 * toolkit be tested without a screen, and drawn by every backend.
 *
 * Coordinates are the playground's: (0, 0) is at the center of the
 * screen, y goes up, and a box is placed by its center like every
 * shape here. So a box at (0, 100) of 200 x 40 spans x from -100 to
 * 100 and y from 80 to 120.
 *
 * Where it stands. This is the bottom of the toolkit: every other
 * module of it speaks [box], [paint] and [input], and nothing below
 * this one knows what a widget is.
 *
 *     Text         Theme         Widget (box, paint, input)
 *      |  \          |          /   |      |      \
 *      |   +------- Look ------+  Layout  Grid   Focus
 *   Text_edit        |
 *      |    +--------+--------+
 *   Immediate     Retained   Mvu       Mvc (a model, and who watches)
 *      |
 *     Gui          the playground's: it makes an [input] of its
 *      |           computer, and shapes of the [paint]
 *   the 7GUIs of examples, mini-drscheme, the office suite
 *
 * A [paint] is the same idea as the playground's own list of shapes
 * (Playground.mli), which Browser_draw makes of a page too: what is
 * to be drawn is written down as data first, and drawn by somebody
 * else. It is what lets four toolkits be compared by comparing
 * lists, with no pixel looked at.
 *
 * terminology:
 * Widget is the word of the X Window System's toolkits (Xt, then
 * Motif and Tk), usually explained as "window gadget". The same
 * thing is a control on Windows and on the Macintosh, a view in
 * NeXTSTEP and Cocoa, a component in Java's Swing and in React, an
 * element on the web. *)

(*****************************************************************************)
(* {1 Boxes: where a widget is} *)
(*****************************************************************************)

(* a rectangle, given by its center, its width and its height *)
type box = { x : float; y : float; w : float; h : float }

(* [contains box px py] is the hit test: is the point (px, py) inside
 * [box]? For example, a button at (0, 100), 200 x 40, contains the mouse
 * at (90, 110) and not at (110, 110). *)
val contains : box -> float -> float -> bool

(* An id tells two widgets apart, so that the state that nobody can
 * hold in the widget itself (who is pressed, who has the keys) can be
 * keyed by something. The id is where the widget is. Immediate.mli says why the
 * rectangle rather than the label, which is what Dear ImGui hashes. *)
type id = float * float

val id : box -> id

(* [inset d box] is the same box, [d] smaller on every side (a
 * border) *)
val inset : float -> box -> box

(* the sides of a box, in playground coordinates (top > bottom) *)
val left : box -> float
val right : box -> float
val top : box -> float
val bottom : box -> float

(*****************************************************************************)
(* {1 What the person does} *)
(*****************************************************************************)

(* This is what a widget knows about the person in this frame:
 * everything the playground's [computer] has that a widget can use,
 * and nothing else (Gui.ml fills it in). [mclick] is true in the
 * frame the button was released, and [typed] holds the characters
 * that frame produced. *)
type input = {
  mx : float;
  my : float;
  mdown : bool;
  mclick : bool;
  (* the right button is held; a context menu opens on its press *)
  mrdown : bool;
  typed : string;
  wheel : float;
  (* every key held down right now, by name, in the playground's
     spelling ("a", "ArrowLeft", "Backspace", "Shift", "space"). These
     are the keys held, not the keys pressed: the frame a key {i goes}
     down is the toolkit's business (Immediate compares with the frame
     before), since a widget wants an edge and a game wants a
     state. *)
  keys : string list;
}

(* nobody touching anything: the mouse is at (0, 0), with no button
 * and no key down *)
val no_input : input

(* This is what a canvas tells its program. A canvas is the one widget
 * whose drawing is the program's: the circles of 7GUIs' Circle
 * Drawer, a chart, a map. It sends [Hover] in every frame where the
 * mouse is over it (and nothing has grabbed the mouse), and then
 * [Press] or [Right_press] in the frame a button goes down there.
 * Each one carries the mouse's point. *)
type canvas_event = Hover of (float * float) | Press of (float * float) | Right_press of (float * float)

(*****************************************************************************)
(* {1 What a widget draws} *)
(*****************************************************************************)

(* A widget draws rectangles of colour, and text. That is all a
 * toolkit of boxes needs: a box with an outline is five rectangles
 * ([frame]), a checkbox's tick is one, and a rounded corner is a thing
 * we do not have. The controls that turn rather than slide (a knob,
 * or a rotary switch, as on a synthesizer's panel) also draw a disc
 * for their face and a segment for the line on it that says where it
 * points.
 *
 * [Text (color, box, s)] centers [s] in [box], at a size of [box.h]:
 * the box is the line the text sits on, not the ink.
 * [Disc (color, x, y, radius)] is centered at (x, y).
 * [Segment (color, width, x1, y1, x2, y2)] is [width] thick, from
 * (x1, y1) to (x2, y2). *)
type paint =
  | Fill of Color.t * box
  | Text of Color.t * box * string
  | Disc of Color.t * float * float * float
  | Segment of Color.t * float * float * float * float * float

(* [frame color thickness box] is the outline of [box], as four fills
 * (top, bottom, left, right), each [thickness] wide and inside the
 * box. *)
val frame : Color.t -> float -> box -> paint list

(* [text_width ~size s] is how wide [s] will be at [size], near enough
 * to place things by. The playground's words are drawn with Hershey's
 * stroke font (graphics/font, 1967) natively and with a sans-serif
 * font on the web, and a glyph there averages 0.6 em: "Save" at size
 * 20 is about 48 pixels wide. That is near enough, but not exact: a
 * widget that must fit its text exactly would have to ask the font,
 * which this side of the toolkit cannot do. *)
val text_width : size:float -> string -> float
