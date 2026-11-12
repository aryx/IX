(* TinyOffice's paint: a picture of fat pixels, painted with the mouse.
 *
 * A paint's data is its picture: one line per row of pixels, and one
 * letter per pixel, giving its colour:
 *
 *     ..kkk..
 *     .krrrk.
 *
 * The letters are . white, k black, r red, g green, b blue, y yellow,
 * o orange, p purple, n brown, a grey (TinyLibPlayground's
 * pixel_letters). A row ends at its last pixel that is not white. A
 * pixel is a 4x4 square on the page. A row is drawn as a single word
 * of the kernel's fat pixels, made of its letters, so a stroke redraws
 * only the rows it went through. A stroke is a line between the places
 * where the mouse was seen, thin or thick (3 pixels).
 *
 * cs-history:
 * MacPaint (Bill Atkinson, 1984) painted a bitmap the same way, moving
 * a brush along with the mouse. Its picture was made of the screen's
 * pixels; this one is made of letters, so the file stays text.
 *)

(* the colours' names, indexed by their number (a paint's ink) *)
val paint_names : string list

(* [pixel_at box x y] is the pixel of the picture under (x, y). *)
val pixel_at : Model.obj -> int -> int -> int * int

(* [paint office ink brush c0 r0 c1 r1] paints a stroke in the selected
 * paint. The undo point was saved when the stroke began. *)
val paint :
  Model.office -> int -> int -> int -> int -> int -> int -> unit

(* [paint_key office brush key]: a digit chooses a colour (0 white,
 * 1 black...); C-g stops editing the paint. *)
val paint_key : Model.office -> int -> TinyLibPlayground.key -> unit

(* Each row is a word of fat pixels. Only the rows that fit in the box
 * are drawn, and of each only as much as fits. *)
val paint_view : Model.obj -> TinyLibPlayground.shape list
