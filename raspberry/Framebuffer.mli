(* The framebuffer's device side (plan_pi.md, decision 9): the geometry
 * the mailbox gave out (channel 1 or the property tags) and the pixels
 * in RAM, as RGB for a display: 16 bits (RGB565, xv6's), 24, 32 (XRGB).
 * Shown through the executable's display (SDL), written as PPM (QMP's
 * screendump). *)

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
