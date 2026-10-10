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
 * from 0. (invisible) to 1. (opaque), like Playground's [fade].
 *
 * A framebuffer 3 pixels wide and 2 high, its top row red, green and
 * blue, its bottom row white, is these 24 bytes:
 *
 *     offset 0            4            8
 *            00 00 FF FF  00 FF 00 FF  FF 00 00 FF     row 0
 *            b  g  r  -
 *     offset 12           16           20
 *            FF FF FF FF  FF FF FF FF  FF FF FF FF     row 1
 *
 *     pixel (x, y) is at 4 * (y * width + x)
 *
 * (In the playground a pixel is one integer, 0xAARRGGBB, in SDL's
 * memory: the same four bytes on a machine that stores the low byte
 * first, the alpha byte there because that is the layout SDL's
 * window surface has, and always 0xFF.)
 *
 * Where it stands: the bottom of ix's other way to draw. The top
 * level of lib_graphics asks the kernel (Display, Draw: the pixels
 * are the kernel's); here they are the program's, found by Line,
 * Fill, Circle, Stroke and Blit, and shown whole: given to the draw
 * device as an image's rows (Display.load_sub; the format is the
 * screen's, x8r8g8b8, so no byte is converted), written as a file,
 * or handed to SDL. A PDF page (Pdf_canvas) and an SVG picture (Svg)
 * are painted in one too. A picture read from a file is not one: it
 * has an alpha and its bytes are red first (Rgba_image).
 *
 * cs-history:
 * A frame's buffer: memory that holds a whole picture, read out to
 * the screen sixty times a second while the program writes in it at
 * its own pace. The first displays had none; they steered the beam
 * along each line of the drawing (Sketchpad's, 1963), since a bit a
 * point of the screen was more memory than a machine had. Richard
 * Shoup's SuperPaint at Xerox PARC (1973) had eight bits a pixel,
 * and the Alto, the same year and place, a bit a pixel for every
 * user: from then on drawing is writing numbers in an array, and
 * the algorithms are those of this directory. *)
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
