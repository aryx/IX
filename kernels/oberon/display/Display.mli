(* The display (Oberon's Display): a frame of 1024 x 768 pixels of two
 * colours, and five operations on it, each in one of three modes. All
 * that Oberon draws is made of them: a text's characters, a viewer's
 * borders and its menu's bar, the caret, the selection, the mouse's
 * arrow (those three by invert: drawn twice, the screen is as it was).
 *
 * A place is (x, y) with the origin at the bottom left, as Oberon's: y
 * grows upwards. What falls outside the frame is not drawn.
 *
 * Oberon's frame is a bit a pixel in the machine's memory, and its
 * operations work on words of 32 of them. The Pi's frame is 16 bits a
 * pixel: here a pixel is one of two such values (the emulator's two
 * colours), and an operation reads a row's piece, changes it, writes
 * it back. *)

val width : int
val height : int

(* A frame: a rectangle of the display and who answers for it, its
 * handler; the frames inside it (a viewer's menu and its contents).
 *
 * A message is anything sent to a handler. Oberon's is a record a
 * module extends (FrameMsg), and a handler tests which extension it
 * got; here it is an exception, OCaml's type that any module adds
 * cases to: a module declares its messages beside its frames
 * (exception Track of ...), and a handler matches those it knows and
 * lets the others go. So a program adds a kind of frame and its
 * messages without a line changed here: Oberon's point. What Oberon
 * keeps in a frame's extension (a text frame's text) is here what its
 * handler, a closure, holds. *)
type msg = exn
type frame = {
  mutable x : int; mutable y : int; mutable w : int; mutable h : int;
  mutable dsc : frame list;
  mutable handle : frame -> msg -> unit;
}
(* a frame of no size yet, with that handler *)
val frame : (frame -> msg -> unit) -> frame
(* the message given to the frame's handler *)
val send : frame -> msg -> unit

(* black is the background *)
type color = Black | White
type mode =
  | Replace                (* the pixels become the colour (a pattern's: its bits the colour, the others black) *)
  | Paint                  (* the pattern's or the area's pixels become white, the others stay *)
  | Invert                 (* they change colour, the others stay *)

(* A pattern: a string whose first byte is its width (32 at most), the
 * second its height, the rest its rows from the lowest, each of (width
 * + 7) / 8 bytes, a pixel a bit, the leftmost the lowest. *)
type pattern = string
val arrow : pattern
val star : pattern
val hook : pattern
val updown : pattern
val block : pattern
val cross : pattern
(* 32 wide, for repl_pattern *)
val grey : pattern

(* (the frame is asked of the board, all black, when this module starts) *)

val dot : color -> int -> int -> mode -> unit
(* [repl_const col x y w h mode]: a rectangle *)
val repl_const : color -> int -> int -> int -> int -> mode -> unit
(* [copy_pattern col pattern x y mode]: its lower left corner at (x, y); Paint or Invert *)
val copy_pattern : color -> pattern -> int -> int -> mode -> unit
(* [copy_block sx sy w h dx dy]: a rectangle's pixels to another place, which it may overlap *)
val copy_block : int -> int -> int -> int -> int -> int -> unit
(* [repl_pattern col pattern x y w h]: a rectangle inverted where the
 * pattern, 32 wide and laid from the frame's left edge, has a bit *)
val repl_pattern : color -> pattern -> int -> int -> int -> int -> unit
