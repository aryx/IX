(* The framebuffer's device side (plan_pi.md, decision 9): the geometry
 * the mailbox gave out (channel 1 or the property tags) and the pixels
 * in RAM, as RGB for a display: 16 bits (RGB565, xv6's), 24, 32 (XRGB).
 * Shown through the executable's display (SDL), written as PPM (QMP's
 * screendump).
 *
 * A framebuffer is the screen as an array in memory: a pixel is a
 * number at an address, and drawing is a store. The pixel at (x, y)
 * of a screen 16 bits deep:
 *
 *     base + y * pitch + x * 2        pitch: the bytes of a row
 *
 *     15       11 10        5 4        0
 *     |   red    |   green   |   blue   |    RGB565: 5, 6 and 5 bits
 *
 * (Green has the bit more: the eye tells greens apart best.) There
 * is no command to draw a line or a letter: the kernel's draw
 * device and, above it, the window system do all of that with
 * stores into this array, and the device's only work is to show
 * the array some tens of times a second. Here that is [raw] or
 * [direct] handed to a Display, or [rgb] made a PPM file.
 *
 * Where it stands: Devices' mailbox calls [configure] when the
 * kernel is given its framebuffer; Board's [frame] and [screen] are
 * this module's; at the other end of ix the pixels are mini-rio's
 * windows, through the kernel's draw device. *)

type geometry = { width : int; height : int; depth : int; pitch : int; base : int }

type t

val create : Memory.t -> t

(* the kernel was given a framebuffer *)
val configure : t -> geometry -> unit

(* width, height, 3 bytes a pixel, row after row; none before the kernel
 * asked for one *)
val rgb : t -> (int * int * string) option

(* the pixels as the kernel wrote them (a display's fast path: no
 * conversion; SDL has RGB565 textures) *)
val raw : t -> (geometry * string) option

(* the same in place, for a display that reads them many times a second
 * (a page's canvas): the RAM's bytes and where the pixels start in them *)
val direct : t -> (geometry * Bytes.t * int) option

(* as a raw PPM (P6) *)
val ppm : int * int * string -> string
