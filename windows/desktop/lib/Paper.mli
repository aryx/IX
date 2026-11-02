(* The desk's wallpaper as pixels, without a screen: a colour made a gradient,
 * or a picture made the screen's size.
 *
 * A picture is scaled to cover all the screen and keep its shape, the rest
 * cut on the two sides that are too long ("cover", as a web page's
 * background-size says it): a wallpaper with bars beside it looks unfinished,
 * one stretched looks wrong. Each pixel the nearest of the picture's: done
 * once, for a picture of a few hundred thousand pixels. *)

(* [bands c]: the colour at the top, then darker down to about a third of it,
 * in [n] steps: the colours, 0xRRGGBB *)
val bands : int -> int -> int list

(* [cover src_w src_h rgba w h]: the picture's rgba bytes, four a pixel,
 * made w by h, as a x8r8g8b8 image is loaded (b, g, r, x) *)
val cover : int -> int -> Bytes.t -> int -> int -> string
