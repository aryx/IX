(* A tiny GUI toolkit: what a program with buttons of TinyKernel.ml's is
 * written on, the essential of a widget toolkit (ix's twin is lib_gui/,
 * the author's playground's, which has four ways to write such a
 * program; this is its last, Mvu). A library, in tiny-ml's ML and
 * OCaml's, given to tiny-ml before the program, after the playground
 * whose shapes it draws by:
 *
 *     tiny-ml -tm -o calc.tm calls.ml TinyLibDraw.ml TinyLibPlayground.ml TinyLibGUI.ml TinyAppCalculator.ml calc.ml
 *     (the last one line: let () = run calculator)
 *
 * The idea kept: {b an interface is a value the model is turned into,
 * and what it sends back}. [view] makes the widgets from the model,
 * each button carrying the message it sends; [update] is the one
 * place the model changes, by a message. The program never draws,
 * never asks where the mouse is, and never tells a widget to change:
 * the widgets are made again from the next model.
 *
 *                 +----------- update <---- a message ----+
 *                 v                                       |
 *     init --> a model --view--> widgets --> shapes, and boxes that
 *                                   ^        answer the mouse
 *                                   |                     ^
 *                          sizes, then places     the mouse, the keys
 *
 * A whole program, a number and a button that makes it one more (the
 * first of the 7GUIs; examples/Gui7Counter.ml is m-ix's):
 *
 *     let counter = {
 *       init = 0;
 *       view = (fun n -> Row [ Field (string_of_int n); Button ("count", 1) ]);
 *       update = (fun by n -> n + by);
 *       key = (fun k -> []) }
 *     let () = run counter
 *
 * What is the library's:
 *
 * - {b The layout, in two passes}: up, each widget says the size it
 *   asks for (a text's, a row as many times its widest widget, a
 *   column its heights added); down, each is given its place (a row
 *   shares its width, a column gives all of it). No widget has a
 *   coordinate in the program.
 * - {b A click is a button's box}: the place gives, with the shapes,
 *   the boxes that answer the mouse and their messages. The button the
 *   mouse went down in sends its message when the mouse comes up in
 *   it; a press is taken back by leaving the button.
 * - {b What is under the model}: one value, the mouse: where its
 *   button went down, where it is, where it last went down. It is not
 *   the model's (no program wants to know of a button half pressed,
 *   nor of a caret) and no widget can keep it, being made again each
 *   time. The button held is the one whose box has the first two
 *   points; the field that has the keys is the one whose box has the
 *   third. So no widget needs a name, and the focus is a place.
 * - {b The model's picture, and what is over it}: the widgets' shapes
 *   are the model's alone, made and placed when the model is another
 *   one; a held button's edges and a field's caret are drawn over
 *   them, from the mouse and the boxes. A press makes no widget.
 * - {b Only what changed is drawn}: the shapes of two views are
 *   compared one by one, and a shape that is another is drawn on the
 *   window, over its own ground. A button pressed is four messages,
 *   whatever the program.
 * - {b A field sends its whole text}: the text is the model's, the
 *   field has none. A key in it sends the text with the character
 *   more, and what shows next is what the model made of it.
 *
 * Dropped, lib_gui's: a caret that moves in its text (it is at the end:
 * a key adds there, a backspace takes from there), a selection, the
 * Tab from a field to the next; sliders, check boxes, menus, lists, a
 * canvas; themes and looks (one: grey,
 * two edges lit); a grid, weights and spans (a row's widgets are the
 * same width, which makes a grid of rows in a column); a window that
 * changes its size (TinyWindows tells no size); time (a program here
 * moves only when the person does); the three other ways (immediate,
 * retained, model-view-controller).
 *
 * Exercises:
 * - a check box: a button whose text says its state, which is the
 *   model's;
 * - the Tab: the keys go to the next field (the focus is a point: the
 *   next box's);
 * - a caret that moves: the arrows, and where it is under the model;
 * - a row that gives each widget the width it asked for, and the rest
 *   to one of them;
 * - the clock: a message every second, for a timer.
 *
 * Where it stands: under it TinyLibPlayground (the shapes and their
 * drawing, not its loop: a game has frames and no mouse), TinyLibDraw and
 * TinyCalls; over it TinyAppCalculator and TinyAppTemperature. It draws on its descriptor 3 and
 * reads its 0 and its 4, so a program runs on the screen or in a
 * window of TinyWindows without knowing. Its mouse is the kernel's
 * box, which keeps the last place only: a click that begins and ends
 * while the program is drawing is not seen. On tiny-machine a press is
 * some 160,000 instructions, 20 ms, most of them its four messages'
 * strings; a click that changes the model 540,000, the calculator's 18
 * widgets made, placed and compared.
 *
 * cs-history:
 * A screen of widgets that send messages is Smalltalk's (Xerox PARC,
 * the 1970s), where a button was an object told of the mouse and
 * telling another object in turn; every toolkit since kept that shape
 * (MacApp, X's Xt and Motif, Tk, Qt), a tree of objects each with its
 * state, changed in place by the program. Plan 9's own, libpanel (Tom
 * Duff), is one of the smallest of that kind. Layout as two passes, a
 * size asked up and a place given down, is TeX's boxes (1978) and
 * Tk's packer (John Ousterhout, 1990).
 *
 * modern:
 * The view as a function of the model, made again at each change, is
 * Elm's (2012) and what React (2013), SwiftUI and Jetpack Compose
 * made the usual way: the program says what the screen is, not how
 * to change it. Their cost is the one paid here, two trees compared
 * to find what to draw (React's "virtual DOM" and its keys); and
 * their awkward corner is the one named above, what is under the
 * model: the focus, a caret, a scroll's place.
 *
 * References: E. Czaplicki, The Elm Architecture (guide.elm-lang.org);
 * E. Kiss, "7GUIs: A GUI Programming Benchmark" (2014); T. Duff,
 * "A Quick Introduction to the Panel Library" (Plan 9); J. Ousterhout,
 * "Tcl and the Tk Toolkit" (1994), the packer. *)

(* a widget: a text; a text in a box, at its right; a field typed in,
 * with the message of another text; a button and the message it
 * sends; widgets side by side, the same width each; widgets one under
 * the other *)
type 'msg widget =
  | Label of string
  | Field of string
  | Input of string * (string -> 'msg)
  | Button of string * 'msg
  | Row of 'msg widget list
  | Col of 'msg widget list

(* a program: its first model, the model as widgets, the model after a
 * message, a key's messages when no field has the keys (none: []) *)
type ('m, 'msg) gui = { init : 'm; view : 'm -> 'msg widget; update : 'msg -> 'm -> 'm; key : int -> 'msg list }

(* The program's loop, with no end but an Escape, a q that no field
 * takes, or the keys' end (the mouse or a key waited for, what changed
 * drawn) *)
val run : ('m, 'msg) gui -> 'a

(* what is under the model: where the mouse's button went down (px -1:
 * it is up), where the mouse is, where its button last went down;
 * [up] at first *)
type mouse = { px : int; py : int; x : int; y : int; fx : int; fy : int }
val up : mouse

(* what a box (x, y, width, height) does: a button's message; a field's
 * text and the message of another one *)
type 'msg action = Send of 'msg | Edit of string * (string -> 'msg)

(* the size a widget asks for; a model's widgets at their places: a
 * shape each, and the boxes that answer the mouse or the keys *)
val size : 'msg widget -> int * int
val laid : ('m, 'msg) gui -> 'm -> TinyLibPlayground.shape list * ((int * int * int * int) * 'msg action) list

(* what is drawn over the widgets, by the mouse: a held button's edges,
 * the caret of the field that has the keys; each with its box *)
val over : ((int * int * int * int) * 'msg action) list -> mouse -> ((int * int * int * int) * TinyLibPlayground.shape) list

(* [mouse g boxes model m x y buttons]: the model and the mouse after
 * the mouse is there; [key g boxes model m k]: the model after a key *)
val mouse : ('m, 'msg) gui -> ((int * int * int * int) * 'msg action) list -> 'm -> mouse -> int -> int -> int -> 'm * mouse
val key : ('m, 'msg) gui -> ((int * int * int * int) * 'msg action) list -> 'm -> mouse -> int -> 'm

(* [redraw shown was now is]: after the shapes shown and what was over
 * them, the shapes now and what is over them, drawn where they differ
 * (a test's: on the window, image 0) *)
val redraw :
  TinyLibPlayground.shape list -> ((int * int * int * int) * TinyLibPlayground.shape) list ->
  TinyLibPlayground.shape list -> ((int * int * int * int) * TinyLibPlayground.shape) list -> unit
