(* This is the framebuffer's device side (plan_pi.md, decision 9). It
 * holds the geometry that the mailbox gave out (on channel 1 or by the
 * property tags), and gives the pixels in RAM as RGB for a display.
 * The pixels can be 16 bits (RGB565, xv6's), 24 bits, or 32 bits
 * (red, green and blue bytes, then one unused). They are shown
 * through the executable's display (SDL), and written as PPM (for
 * QMP's screendump).
 *
 * A framebuffer is the screen as an array in memory: a pixel is a
 * number at an address, and drawing is a store. Here is the pixel at
 * (x, y) of a screen 16 bits deep:
 *
 *     base + y * pitch + x * 2        pitch: the bytes in a row
 *
 *     15       11 10        5 4        0
 *     |   red    |   green   |   blue   |    RGB565: 5, 6 and 5 bits
 *
 * (Green has one bit more, because the eye tells greens apart best.)
 * There is no command to draw a line or a letter. The kernel's draw
 * device and, above it, the window system do all of that with stores
 * into this array, and the device's only work is to show the array
 * some tens of times a second. Here that work is [raw] or [direct]
 * handed to a Display, or [rgb] made into a PPM file.
 *
 * Where it stands: Devices' mailbox calls [configure] when the kernel
 * is given its framebuffer. Board's [frame] and [screen] come from
 * this module. At the other end of ix, the pixels are mini-rio's
 * windows, drawn through the kernel's draw device. *)

type geometry = { width : int; height : int; depth : int; pitch : int; base : int }

type t

val create : Memory.t -> t

(* [configure] is called when the kernel was given a framebuffer *)
val configure : t -> geometry -> unit

(* the width, the height, and the pixels at 3 bytes each, row after
 * row; none before the kernel asked for a framebuffer *)
val rgb : t -> (int * int * string) option

(* the pixels as the kernel wrote them. This is a display's fast path,
 * with no conversion, since SDL has RGB565 textures. *)
val raw : t -> (geometry * string) option

(* the same pixels in place, for a display that reads them many times a
 * second (a page's canvas): the RAM's bytes, and where the pixels start
 * in them *)
val direct : t -> (geometry * Bytes.t * int) option

(* [ppm] writes a screen as a raw PPM (P6) *)
val ppm : int * int * string -> string
