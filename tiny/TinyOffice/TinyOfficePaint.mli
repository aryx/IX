(* TinyOffice's paint: a picture of fat pixels, painted with the mouse.
 *
 * A paint's data is its picture, a line a row of pixels, a letter a
 * pixel, its colour:
 *
 *     ..kkk..
 *     .krrrk.
 *
 * . white, k black, r red, g green, b blue, y yellow, o orange, p
 * purple, n brown, a grey (TinyLibPlayground's pixel_letters; a row
 * ends at its last colour that is not white). A pixel is a square of 4
 * by 4 on the page; a row is one word of the kernel's fat pixels, its
 * letters, so a stroke draws again the rows it went through, and
 * nothing else. A stroke is a line between the places the mouse was
 * seen at, thin or thick (3 pixels).
 *
 * cs-history:
 * MacPaint (Bill Atkinson, 1984) painted a bitmap the same way, a
 * brush along the mouse; its picture was the screen's pixels, this one
 * is letters, so the file stays text.
 *)

(* the colours' names, by their number (a paint's ink) *)
val paint_names : string list

(* [pixel_at box x y]: the pixel under (x, y), in the picture *)
val pixel_at : TinyOfficeModel.obj -> int -> int -> int * int

(* [paint office ink brush c0 r0 c1 r1]: a stroke painted in the
 * selected paint (the page changed, its undo kept when the stroke
 * began) *)
val paint :
  TinyOfficeModel.office -> int -> int -> int -> int -> int -> int -> unit

(* [paint_key office brush key]: a digit a colour (0 white, 1
 * black...); C-g leaves it *)
val paint_key : TinyOfficeModel.office -> int -> int -> unit

(* each row a word of fat pixels, the rows that fit, as much of each as
 * fits *)
val paint_view : TinyOfficeModel.obj -> TinyLibPlayground.shape list
