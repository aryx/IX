(* The desk's wallpaper as pixels, computed without a screen: a colour
 * made into a gradient, or a picture made the screen's size.
 *
 * A picture is scaled to cover all the screen and keep its shape, and
 * the rest is cut on the two sides that are too long ("cover", as a web
 * page's background-size says it). A wallpaper with bars beside it
 * looks unfinished, and one that is stretched looks wrong. Each pixel
 * is the nearest of the picture's pixels, and this is done once, for a
 * picture of a few hundred thousand pixels. *)

(* [bands n c] is the colours, as 0xRRGGBB: the colour at the top, then
 * darker ones down to about a third of it, in [n] steps *)
val bands : int -> int -> int list

(* [cover src_w src_h rgba w h] is the picture's rgba bytes, four per
 * pixel, made w by h, as a x8r8g8b8 image is loaded (b, g, r, x) *)
val cover : int -> int -> Bytes.t -> int -> int -> string
