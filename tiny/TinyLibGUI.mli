(* A tiny GUI toolkit: the library on which programs with buttons for
 * TinyKernel.ml are written. It keeps the essentials of a widget
 * toolkit. Its full-size counterpart in ix is lib_gui/, from the
 * author's playground, which offers four ways to write such a
 * program; this library keeps only the last one, Mvu. It draws with
 * the playground's shapes.
 *
 * The main idea is that {b an interface is a value computed from the
 * model, together with the messages it sends back}. [view] builds the widgets
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
 * Here is a whole program. It shows a number, and a button that adds
 * one to it (the first of the 7GUIs; examples/Gui7Counter.ml is the m-ix
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
 *   needs (a text needs its own size, a row its widest widget times
 *   the number of widgets, and a column the sum of their heights). Going down,
 *   each widget is given its position (a row shares its width among
 *   its widgets, a column gives each of them its full width). No
 *   widget has a coordinate in the program.
 * - {b A click lands in a button's box.} Placing the widgets produces,
 *   along with the shapes, the boxes that respond to the mouse, each
 *   with its message. A button sends its message when the mouse is
 *   released inside the same button it was pressed in; moving out of
 *   the button cancels the press.
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
 * dropped:
 * From lib_gui, this library drops:
 * - a caret that moves inside the text (it stays at the end, where a
 *   key adds and a backspace removes), a selection, and Tab to go from
 *   one field to the next;
 * - sliders, check boxes and lists;
 * - themes and looks (there is only one: grey, with two edges lit);
 * - a grid, weights and spans (the widgets of a row all have the same
 *   width, which gives a grid when rows are put in a column);
 * - a window that changes size (TinyWindows does not tell programs
 *   their size);
 * - time (a program here only changes when the user does something);
 * - the three other ways to write a program (immediate, retained,
 *   model-view-controller).
 *
 * twist:
 * {b The state below the model} is just three points, where lib_gui
 * keeps a focus of its own (its Focus module) and relies on the
 * platform for the rest. The three points describe the mouse: where
 * its button went down, where it is now, and where it last went down.
 * This state does not belong in the model (no program wants to know about a
 * half-pressed button or a caret), and no widget can keep it, since
 * widgets are rebuilt every time. The button being held is the one
 * whose box contains the first two points; the field that receives the
 * keys is the one whose box contains the third. So no widget needs a
 * name, and the focus is just a position.
 *
 * archi:
 * The library offers three ways to make a program, each in its own
 * part of this file, from the one where the library does the most to
 * the one where it does the least:
 * - {b the widgets} ([run]), above: the program is a model, a view and
 *   an update; the library lays out, draws and answers the mouse
 *   (TinyAppCalculator, TinyAppTemperature);
 * - {b the menus} ([menu_mouse], [menu_view]): a bar of pull-down menus
 *   for a program that draws its own window (the office, the browser);
 *   the program keeps the menus' state in its model, the way this
 *   library keeps the widgets' mouse;
 * - {b the canvas} ([run_canvas]): the program draws its whole window
 *   as shapes (emacs, the office, the debugger), and the library draws
 *   only what changed, comparing the shapes' leaves (rectangles and
 *   words at their places), as [redraw] compares the widgets' shapes.
 *
 * context:
 * Below this library are TinyLibPlayground, TinyLibDraw and
 * TinyLibSystem. We use the playground's shapes and its drawing, but not
 * its loop, which is made for a game, with frames and no mouse. Above it are
 * TinyAppCalculator, TinyAppTemperature, and the programs that draw
 * their own window (emacs, the office, the debugger, the browser). The
 * library draws on fd_draw and reads fd_stdin and fd_mouse, so a
 * program runs on the screen or in a window of TinyWindows without
 * knowing which. Its mouse is the kernel's box, which keeps only the
 * last position, so a click that starts and ends while the program is
 * drawing is missed. On tiny-machine a press
 * costs about 160,000 instructions (20 ms), mostly for building the
 * strings of its four messages; a click that changes the model costs
 * 540,000, for building, placing and comparing the 18 widgets of the
 * calculator.
 *
 * exercises:
 * - a check box: a button whose text shows its state, which lives in
 *   the model;
 * - Tab: send the keys to the next field (the focus is a point, so it
 *   becomes a point in the next box);
 * - a caret that moves with the arrows, with its position kept below
 *   the model;
 * - a row that gives each widget the width it asked for, and the rest
 *   to one of them;
 * - a clock that sends a message every second, for a timer;
 * - undo and redo in the library, with a stack of past models. Every
 *   program would get them for free, since update is the only place
 *   where the model changes (Elm's time travel).
 *
 * cs-history:
 * A screen of widgets that send messages comes from Smalltalk (Xerox
 * PARC, the 1970s), where a button was an object notified of the mouse
 * which in turn notified another object. Every toolkit since has kept
 * that shape (MacApp, X's Xt and Motif, Tk, Qt): a tree of objects,
 * where each object has its own state and the program changes it in
 * place. Plan 9's
 * own toolkit, libpanel (Tom Duff), is one of the smallest of that
 * kind. Layout in two passes, where sizes are requested going up and
 * positions are given going down, comes from TeX's boxes (1978) and Tk's packer
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
 * references:
 *  - E. Czaplicki, The Elm Architecture (guide.elm-lang.org)
 *  - E. Kiss, "7GUIs: A GUI Programming Benchmark" (2014)
 *  - T. Duff, "A Quick Introduction to the Panel Library" (Plan 9)
 *  - J. Ousterhout, "Tcl and the Tk Toolkit" (1994): the packer
 *)

type 'msg widget =
  | Label of string
  | Field of string (* a text shown in a box *)
  | Input of string * (string -> 'msg) (* each change sends a message *)
  | Button of string * 'msg
  | Row of 'msg widget list (* all the same width *)
  | Col of 'msg widget list

(* [key] gives the messages for a key that no field takes. *)
type ('m, 'msg) gui = {
  init : 'm; view : 'm -> 'msg widget; update : 'msg -> 'm -> 'm;
  key : TinyLibPlayground.key -> 'msg list;
}

(* The loop. It draws only what changed, and ends on Escape, on a q that
 * no field takes, or when the keys end. It returns Exit.OK for a main. *)
val run : ('m, 'msg) gui -> Exit.t

(* a point in the window, in pixels *)
type point = int * int

(* The state below the model, [up] at first. [m_down] is None while the
 * button is up. The field at [m_focus], where the last press was,
 * receives the keys. *)
type mouse = { m_down : point option; m_at : point; m_focus : point option }
val up : mouse

(* a box: x, y, width, height, in pixels *)
type box = int * int * int * int

type 'msg action = Send of 'msg | Edit of string * (string -> 'msg)

(* the boxes that answer the mouse or the keys, each with its action *)
type 'msg boxes = (box * 'msg action) list

val size : 'msg widget -> int * int
val laid : ('m, 'msg) gui -> 'm -> TinyLibPlayground.shape list * 'msg boxes

(* [place x y w h widget] is [laid] for a few widgets in a window the
 * program draws itself, like the browser's toolbar. *)
val place :
  int -> int -> int -> int -> 'msg widget ->
  TinyLibPlayground.shape list * 'msg boxes

(* the edges of a held button and the caret of the focused field *)
val over : 'msg boxes -> mouse -> (box * TinyLibPlayground.shape) list

(* [mouse g boxes model m x y buttons] handles the mouse after it moves
 * to (x, y), and gives the new model and mouse state. *)
val mouse :
  ('m, 'msg) gui -> 'msg boxes -> 'm -> mouse -> int -> int -> int ->
  'm * mouse
val key :
  ('m, 'msg) gui -> 'msg boxes -> 'm -> mouse -> TinyLibPlayground.key -> 'm

(* [redraw shown was now is] draws only where the new shapes and what is
 * over them differ from the old ones. The tests draw on image 0. *)
val redraw :
  TinyLibPlayground.shape list -> (box * TinyLibPlayground.shape) list ->
  TinyLibPlayground.shape list -> (box * TinyLibPlayground.shape) list ->
  unit

(* Pull-down menus, for a program that draws its whole window, like the
 * office. The program keeps a menu_state in its model, starting with
 * [menu_closed ()], and [menu_mouse] changes it in place. Since it is
 * mutable, a program cannot detect a change with [!=]: the browser
 * compares the open menu and the item before and after, and the office
 * compares the shapes of its picture.
 *
 * A press on a title opens its menu; releasing the button on an item
 * chooses it, and releasing it on the title leaves the menu open until
 * the next click. Only the position at release counts, not the path the
 * mouse took to get there. *)
type menu_state = {
  mutable opened : int option;
  mutable item : int option;
  mutable held : int; (* the buttons as last seen *)
}
val menu_closed : unit -> menu_state

(* the menus' height in pixels, at the top of the window *)
val bar_height : int

(* [Ignored] leaves the mouse to the program. *)
type 'msg menu_answer = Ignored | Taken | Picked of 'msg

(* Each title with its items, where each item is a text and its
 * message. *)
type 'msg menus = (string * (string * 'msg) list) list

(* [menu_mouse menus state x y buttons] handles the mouse for the
 * menus. In [buttons], 1 is the left button. *)
val menu_mouse :
  'msg menus -> menu_state -> int -> int -> int -> 'msg menu_answer

(* [menu_view width menus state] gives the bar and the open menu, to draw
 * last, over the program's own shapes. *)
val menu_view : int -> 'msg menus -> menu_state -> TinyLibPlayground.shape list

val inside : int -> int -> box -> bool
val focused : mouse -> box -> bool

(* A program that draws its whole window, like emacs or the office.
 * [first] gets the window size in pixels. The first shape of [picture]
 * covers the whole window. The buttons of [moved] are 1 left, 2 middle,
 * 4 right. A None from [typed] or [moved] ends the program. *)
type 'm canvas = {
  first : int -> int -> 'm; picture : 'm -> TinyLibPlayground.shape list;
  typed : TinyLibPlayground.key -> 'm -> 'm option;
  moved : int -> int -> int -> 'm -> 'm option;
}

(* [run_canvas c] runs until None or the end of the keys, then paints the
 * window white. Each change redraws only the leaves (rectangles and
 * words) that differ from the old ones at the same place, after
 * repainting what lies under them; a word is redrawn from its first
 * differing character. The console is raw meanwhile, so ^C is a key. *)
val run_canvas : < Cap.clock; Cap.keyboard; .. > -> 'm canvas -> unit

(* The window's size. Inside tiny-windows, it is the answer to an ENQ;
 * with no answer within half a second, it is the whole screen of the
 * console. *)
val window_size : < Cap.clock; .. > -> int * int
