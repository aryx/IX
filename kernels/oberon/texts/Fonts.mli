(* Oberon's fonts (Fonts): a file of the disk, Oberon10.Scn.Fnt, is a
 * font's 128 characters, each a box and a pattern of bits, of any
 * width: the look of an Oberon screen. Read as Fonts.Mod reads them.
 *
 * A character is drawn from the pen's place (x, the line's base y):
 * its pattern at (x + c.x, y + c.y), the pen then moved by c.dx. *)

type char_ = {
  dx : int;                (* the pen's move *)
  x : int; y : int;        (* the pattern's corner from the pen and the base line (y: below, when negative) *)
  w : int; h : int;
  pattern : string;        (* Display's: w, h, then the rows, the lowest first *)
}

type t = {
  name : string;
  height : int;            (* a line's *)
  min_x : int; max_x : int; min_y : int; max_y : int;
  chars : char_ array;     (* 128: one not in the font has an empty pattern *)
}

(* the font of that file; the default one when there is no such font.
 * Read once. *)
val this : string -> t
(* Oberon10.Scn.Fnt *)
val default : unit -> t
val get : t -> char -> char_
(* the fonts read so far *)
val names : unit -> string list
