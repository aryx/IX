(* A tiny GUI toolkit: what a program with buttons of TinyKernel.ml's is
 * written on, the essential of a widget toolkit (ix's twin is lib_gui/,
 * the author's playground's, which has four ways to write such a
 * program; this is its last, Mvu). A library, in tiny-ml's ML and
 * OCaml's, given to tiny-ml before the program, after the playground
 * whose shapes it draws by:
 *
 *     tiny-ml -tm -o calc.tm calls.ml TinyDraw.ml TinyPlayground.ml TinyGUI.ml TinyCalculator.ml calc.ml
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
 * - {b What is under the model}: one value, where the mouse's button
 *   went down. It is not the model's (no program wants to know of a
 *   button half pressed) and no widget can keep it, being made again
 *   each time: a button is drawn held when that point and the mouse
 *   are both in the box it is given, so no widget needs a name.
 * - {b Only what changed is drawn}: the shapes of two views are
 *   compared one by one, and a shape that is another is drawn on the
 *   window, over its own ground. A button pressed is four messages,
 *   whatever the program.
 *
 * Dropped, lib_gui's: a field one types in, and with it the focus and
 * the caret (which would be a second value under the model); sliders,
 * check boxes, menus, lists, a canvas; themes and looks (one: grey,
 * two edges lit); a grid, weights and spans (a row's widgets are the
 * same width, which makes a grid of rows in a column); a window that
 * changes its size (TinyWindows tells no size); time (a program here
 * moves only when the person does); the three other ways (immediate,
 * retained, model-view-controller).
 *
 * Exercises:
 * - a check box: a button whose text says its state, which is the
 *   model's;
 * - a field one types in: who has the keys is a second value under the
 *   model, a box as the mouse's; then the temperature converter;
 * - a row that gives each widget the width it asked for, and the rest
 *   to one of them;
 * - the clock: a message every second, for a timer.
 *
 * Where it stands: under it TinyPlayground (the shapes and their
 * drawing, not its loop: a game has frames and no mouse), TinyDraw and
 * TinyCalls; over it TinyCalculator. It draws on its descriptor 3 and
 * reads its 0 and its 4, so a program runs on the screen or in a
 * window of TinyWindows without knowing. Its mouse is the kernel's
 * box, which keeps the last place only: a click that begins and ends
 * while the program is drawing is not seen.
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

(* a widget: a text; a text in a box, at its right; a button and the
 * message it sends; widgets side by side, the same width each; widgets
 * one under the other *)
type 'msg widget = Label of string | Field of string | Button of string * 'msg | Row of 'msg widget list | Col of 'msg widget list

(* a program: its first model, the model as widgets, the model after a
 * message, a key's messages (none: [], a key that says nothing) *)
type ('m, 'msg) gui = { init : 'm; view : 'm -> 'msg widget; update : 'msg -> 'm -> 'm; key : int -> 'msg list }

(* The program's loop, with no end but a q or the keys' end (the mouse
 * or a key waited for, the widgets that changed drawn) *)
val run : ('m, 'msg) gui -> 'a

(* what is under the model: where the mouse's button went down (px -1:
 * it is up) and where the mouse is; [up] at first *)
type mouse = { px : int; py : int; x : int; y : int }
val up : mouse

(* the size a widget asks for; a model's widgets at their places: a
 * shape each, and the boxes (x, y, width, height) that answer the
 * mouse with their messages *)
val size : 'msg widget -> int * int
val laid : ('m, 'msg) gui -> 'm -> mouse -> TinyPlayground.shape list * ((int * int * int * int) * 'msg) list

(* [mouse g model m x y buttons]: the model and the mouse after the
 * mouse is there; [key g model k]: the model after a key *)
val mouse : ('m, 'msg) gui -> 'm -> mouse -> int -> int -> int -> 'm * mouse
val key : ('m, 'msg) gui -> 'm -> int -> 'm

(* the shapes to draw after those shown, drawn (a test's: on the
 * window, image 0) *)
val redraw : TinyPlayground.shape list -> TinyPlayground.shape list -> unit
