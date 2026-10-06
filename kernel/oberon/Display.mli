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
 * it back. The frames and their messages (Display.Frame, FrameMsg) are
 * for the viewers' stage. *)

val width : int
val height : int

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

(* the frame asked of the board, all black (the boot's) *)
val init : unit -> unit

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
