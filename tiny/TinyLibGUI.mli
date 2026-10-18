(* A tiny GUI toolkit: the library on which programs with buttons for
 * TinyKernel.ml are written. It keeps the essentials of a widget
 * toolkit. Its full-size counterpart in ix is lib_gui/, from the
 * author's playground, which offers four ways to write such a
 * program; this library keeps only the last one, Mvu. It is written
 * in the subset of ML that both tiny-ml and OCaml accept, and is
 * given to tiny-ml before the program and after the playground, whose
 * shapes it uses for drawing:
 *
 *     tiny-ml -tm -o calc.tm calls.ml TinyLibDraw.ml TinyLibPlayground.ml TinyLibGUI.ml TinyAppCalculator.ml calc.ml
 *     (the last one line: let () = run calculator)
 *
 * The main idea: {b an interface is a value computed from the model,
 * together with the messages it sends back}. [view] builds the widgets
 * from the model, and each button carries the message it sends.
 * [update] is the only place where the model changes, in response to
 * a message. The program never draws, never asks where the mouse is,
 * and never tells a widget to change: the widgets are simply rebuilt
 * from the next model.
 *
 *                 +----------- update <---- a message ----+
 *                 v                                       |
 *     init --> a model --view--> widgets --> shapes, and boxes that
 *                                   ^        respond to the mouse
 *                                   |                     ^
 *                       sizes, then positions     the mouse, the keys
 *
 * Here is a whole program: a number, and a button that adds one to it
 * (the first of the 7GUIs; examples/Gui7Counter.ml is the m-ix
 * version):
 *
 *     let counter = {
 *       init = 0;
 *       view = (fun n -> Row [ Field (string_of_int n); Button ("count", 1) ]);
 *       update = (fun by n -> n + by);
 *       key = (fun k -> []) }
 *     let () = run counter
 *
 * What the library takes care of:
 *
 * - {b Layout, in two passes.} Going up, each widget says what size it
 *   needs (a text its own size, a row its widest widget times the
 *   number of widgets, a column the sum of their heights). Going down,
 *   each widget is given its position (a row shares its width among
 *   its widgets, a column gives each of them its full width). No
 *   widget has a coordinate in the program.
 * - {b A click is a box of a button.} Placing the widgets produces,
 *   along with the shapes, the boxes that respond to the mouse and
 *   their messages. A button sends its message when the mouse is
 *   released inside the same button it was pressed in; moving out of
 *   the button cancels the press.
 * - {b The state below the model.} There is one such value, the mouse:
 *   where its button went down, where it is now, and where it last
 *   went down. This state does not belong in the model (no program
 *   wants to know about a half-pressed button or a caret), and no
 *   widget can keep it, since widgets are rebuilt every time. The
 *   button being held is the one whose box contains the first two
 *   points; the field that receives the keys is the one whose box
 *   contains the third. So no widget needs a name, and the focus is
 *   just a position.
 * - {b The picture of the model, and what is drawn over it.} The
 *   shapes of the widgets depend only on the model; they are built and
 *   placed only when the model changes. The edges of a held button and
 *   the caret of a field are drawn on top of them, from the mouse and
 *   the boxes. A press does not rebuild any widget.
 * - {b Only what changed is drawn.} The shapes of two views are
 *   compared one by one, and a shape that differs is drawn on the
 *   window over its own background. Pressing a button costs four
 *   messages, whatever the program.
 * - {b A field sends its whole text.} The text belongs to the model;
 *   the field has none of its own. A key typed in a field sends the
 *   text with the new character added, and what is displayed next is
 *   whatever the model made of it.
 *
 * What is dropped from lib_gui: a caret that moves inside the text (it
 * stays at the end, where a key adds and a backspace removes), a
 * selection, Tab to go from one field to the next; sliders, check
 * boxes, lists; themes and looks (there is only one: grey, with two
 * edges lit); a grid, weights and spans (the widgets of
 * a row all have the same width, which gives a grid when rows are put
 * in a column); a window that changes size (TinyWindows does not tell
 * programs their size); time (a program here only changes when the
 * user does something); and the three other ways to write a program
 * (immediate, retained, model-view-controller).
 *
 * Exercises:
 * - a check box: a button whose text shows its state, which lives in
 *   the model;
 * - Tab: send the keys to the next field (the focus is a point, so it
 *   becomes a point in the next box);
 * - a caret that moves with the arrows, its position kept below the
 *   model;
 * - a row that gives each widget the width it asked for, and the rest
 *   to one of them;
 * - a clock: a message every second, for a timer.
 *
 * Where it stands: below it are TinyLibPlayground (its shapes and
 * their drawing, but not its loop, because a game has frames and no
 * mouse), TinyLibDraw and TinyCalls; above it are TinyAppCalculator
 * and TinyAppTemperature. It draws on its descriptor 3 and reads its
 * 0 and its 4, so a program runs on the screen or in a window of
 * TinyWindows without knowing which. Its mouse is the kernel's box,
 * which keeps only the last position, so a click that starts and ends
 * while the program is drawing is missed. On tiny-machine a press
 * costs about 160,000 instructions (20 ms), mostly for building the
 * strings of its four messages; a click that changes the model costs
 * 540,000, for building, placing and comparing the 18 widgets of the
 * calculator.
 *
 * cs-history:
 * A screen of widgets that send messages comes from Smalltalk (Xerox
 * PARC, the 1970s), where a button was an object notified of the mouse
 * which in turn notified another object. Every toolkit since has kept
 * that shape (MacApp, X's Xt and Motif, Tk, Qt): a tree of objects,
 * each with its own state, changed in place by the program. Plan 9's
 * own toolkit, libpanel (Tom Duff), is one of the smallest of that
 * kind. Layout in two passes, sizes requested going up and positions
 * given going down, comes from TeX's boxes (1978) and Tk's packer
 * (John Ousterhout, 1990).
 *
 * modern:
 * Treating the view as a function of the model, rebuilt at each
 * change, comes from Elm (2012), and React (2013), SwiftUI and Jetpack
 * Compose made it the usual way: the program says what the screen is,
 * not how to change it. They pay the same cost as here, comparing two
 * trees to find what to redraw (React's "virtual DOM" and its keys),
 * and their awkward corner is the same one described above: the state
 * below the model, such as the focus, a caret, or a scroll position.
 *
 * References: E. Czaplicki, The Elm Architecture (guide.elm-lang.org);
 * E. Kiss, "7GUIs: A GUI Programming Benchmark" (2014); T. Duff,
 * "A Quick Introduction to the Panel Library" (Plan 9); J. Ousterhout,
 * "Tcl and the Tk Toolkit" (1994), for the packer. *)

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

(* [place x y w h widget]: a widget given that box, as [laid] places a
 * model's (a program that draws its own window and has a few widgets
 * on it: the browser's toolbar) *)
val place : int -> int -> int -> int -> 'msg widget -> TinyLibPlayground.shape list * ((int * int * int * int) * 'msg action) list

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

(* Pull-down menus, for a program that draws its whole window (the
 * office): a bar of titles across its top, each a menu of items, each
 * item a text and the message it sends (a list: [(title, [(text,
 * message); ...]); ...]). As the widgets' mouse, what
 * the menus keep is below the model: which menu is open, the item
 * under the mouse, the buttons as last seen (a value to keep in the
 * model, changed by [menu_mouse]; [menu_closed ()] at first).
 *
 * A press on a title opens its menu; the button held, the mouse goes
 * along the titles and down the items; let go on an item, it is
 * chosen. Let go on the title, the menu stays open, for a click on an
 * item; a click elsewhere closes it. The mouse being a place, not its
 * history, what counts is where it is when the button goes up: a press
 * on a title and a let go on an item, with nothing seen between, is a
 * choice. *)
type menu_state = { mutable opened : int; mutable item : int; mutable held : int }
val menu_closed : unit -> menu_state

(* the menus' height in pixels, at the top of the window *)
val bar_height : int

(* what the menus did with the mouse: nothing (it is the program's), it
 * was theirs, an item chosen and its message *)
type 'msg menu_answer = Ignored | Taken | Picked of 'msg

(* [menu_mouse menus state x y buttons] *)
val menu_mouse : (string * (string * 'msg) list) list -> menu_state -> int -> int -> int -> 'msg menu_answer

(* [menu_view width menus state]: the bar, the open menu: two shapes,
 * drawn last, over the program's *)
val menu_view : int -> (string * (string * 'msg) list) list -> menu_state -> TinyLibPlayground.shape list

(* a point in a box (x, y, width, height) *)
val inside : int -> int -> int * int * int * int -> bool

(* A program that draws its whole window, below the widgets (emacs,
 * the office): its first model, given its window's size in pixels; its
 * picture as shapes, the first one the ground under all (a rectangle
 * of the whole window); a key and the next model, or None to end; the
 * mouse at (x, y) and its buttons (1 left, 2 middle, 4 right), and the
 * next model, or None *)
type 'm canvas = { first : int -> int -> 'm; picture : 'm -> TinyLibPlayground.shape list; typed : int -> 'm -> 'm option; moved : int -> int -> int -> 'm -> 'm option }

(* [run_canvas c]: the program until its typed says None or the keys
 * end; then its window white. After each key (or each read of the
 * keys) and each move of the mouse, its picture is drawn where it
 * changed: each shape's leaves (its rectangles and words at their
 * places) compared with the old shape's at their place; what changed
 * erased by the ground and what is on it there, the new drawn; words
 * at the same place drawn from their first other character. The
 * console is raw meanwhile, its ^C a key. *)
val run_canvas : 'm canvas -> unit

(* the window's size in pixels: tiny-windows' answer to an ENQ, or
 * the console's 640 by 480 *)
val window_size : unit -> int * int

(* the file such a program edits: its text ("" when it is not there);
 * the text written, and whether all of it was *)
val read_file : string -> string
val write_file : string -> string -> bool
