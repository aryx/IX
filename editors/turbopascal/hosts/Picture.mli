(* A picture in memory with Plan 9's default font's characters drawn in
 * it, by this program itself: what a host that is not Plan 9's draw
 * device shows (an SDL window's pixels, a file). The font's bits are
 * Font_default's, read as Font reads them and put where Font.string
 * puts them: a screen of cells painted here is, pixel for pixel, the
 * one the draw device paints. *)

(* w by h pixels, each three bytes: red, green, blue *)
type t = { w : int; h : int; pixels : Bytes.t }

(* (black) *)
val create : int -> int -> t

(* the font, and a cell's size with it: 9 by 15 *)
type font
val font : unit -> font
val cell : font -> int * int

(* Cells's surface on a picture *)
val surface : t -> font -> Cells.surface

(* as a file: a PPM (P6) *)
val ppm : t -> string
