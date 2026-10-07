(* A framebuffer: the grid of pixels an image is made of, as one big
 * array of numbers in memory -- the thing every other module in graphics/
 * writes into, and the thing the screen displays.
 *
 * Pixel (x, y) is column x, row y, with (0, 0) the top-left corner and
 * y going *down* (the convention of screens, image files, and SDL --
 * not Elm's, see Affine for the conversion). Each pixel is four bytes:
 * blue, green, red, and one that is not used (always 0xFF). For
 * example 00 00 CC FF is Playground's [red], "#cc0000".
 *
 * Colors passed to the functions below are 0xRRGGBB ints (no alpha
 * byte; e.g. 0xcc0000), and transparency is a separate [alpha] float,
 * from 0. (invisible) to 1. (opaque), like Playground's [fade]. *)
(* ix: the author's playground's libs/graphics/core/Framebuffer.mli (docs/plans/plan_playground.md) *)

(* ix: the playground's has SDL's memory here (a Bigarray of 32-bit
 * integers, the window's surface). This one has the bytes Plan 9's
 * draw device takes for an image of format x8r8g8b8 (a pixel's 32
 * bits, the low byte first): rows from the top, pixel (x, y) at offset
 * 4 * (y * width + x). So a frame is given to the device as it is, no
 * copy made of it (Display.load). *)
type pixels = Bytes.t

type t = { width : int; height : int; pixels : pixels }

(* A new framebuffer, all white; for offscreen drawing and tests *)
val create : width:int -> height:int -> t

(* A framebuffer on top of existing memory: 4 * width * height bytes *)
val of_pixels : width:int -> height:int -> pixels -> t

(* Fill the whole framebuffer with one (opaque) color *)
val clear : t -> rgb:int -> unit

(* The 0xRRGGBB color of pixel (x, y) (for tests and debugging) *)
val get_rgb : t -> x:int -> y:int -> int

(* [fill_span fb ~y ~x0 ~x1 ~rgb ~alpha] paints the horizontal run of
 * pixels x0, x0+1, ..., x1-1 of row y ("span" is the classic name for
 * it). Everything that fills an area -- rectangles, polygons, circles --
 * ends up as a series of spans, one per row; the difference between
 * those shapes is only how each row's [x0, x1) is computed. Parts
 * outside the framebuffer are silently skipped (clipped), so callers
 * don't have to care. With [alpha] < 1., the color is blended over what
 * is already there (see [blend]). *)
val fill_span : t -> y:int -> x0:int -> x1:int -> rgb:int -> alpha:float -> unit

(* One pixel: fill_span of length 1; skipped if outside *)
val plot : t -> x:int -> y:int -> rgb:int -> alpha:float -> unit

(* [blend ~src ~dst ~alpha] is the color you get by painting [src] with
 * opacity [alpha] over an opaque [dst], i.e. Porter & Duff's "src over
 * dst", channel by channel: src * alpha + dst * (1 - alpha). For
 * example, half-transparent red over white:
 *   blend ~src:0xff0000 ~dst:0xffffff ~alpha:0.5 = 0xff8080 (pink)
 *
 * Reference: Thomas Porter, Tom Duff, "Compositing Digital Images",
 * SIGGRAPH '84 (Computer Graphics 18(3):253-259). *)
val blend : src:int -> dst:int -> alpha:float -> int
