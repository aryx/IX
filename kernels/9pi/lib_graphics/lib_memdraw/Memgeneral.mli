(* The general loop of memdraw, in a file of its own. It reads every
 * pixel of the source and of the mask, composes it with the
 * destination's by the operator, and writes the result (as alphadraw.c
 * does, without its buffers). Memdraw calls it when none of its faster
 * paths handles the case.
 *
 *     dst(x, y) <- fs * src + fd * dst      (each channel, MUL's rounding)
 *     SoverD:  fs = the mask's coverage, fd = 255 - MUL(src's alpha, coverage)
 *
 * design:
 * It is a file of its own because a machine's host can run it too. It
 * reads and writes an image's bytes through Memimage only, and those
 * bytes may be anywhere. When the kernel is built for a web page, its
 * Memdraw's draw asks mini-qemu's board to draw (Hostdraw on the
 * board's side), and the board runs this same file, compiled for the
 * host, on the images where they are in the board's memory. The pixels
 * are then the same by construction, and the loop runs on the host and
 * not in the emulator: one of rio's menus took 20 million instructions
 * here.
 *
 * Pike, "draw - screen graphics" (Plan 9 manual, draw(2)); Porter and
 * Duff, "Compositing Digital Images" (SIGGRAPH 1984). *)

(* MUL is x*y/255, with memdraw's rounding *)
val mul : int -> int -> int

(* the operators (draw.h's Drawop) *)
val o_clear : int
val o_douts : int
val o_souts : int
val o_dins : int
val o_d : int
val o_datops : int
val o_dovers : int
val o_sind : int
val o_satopd : int
val o_s : int
val o_soverd : int

(* how much a mask covers a pixel, given the r, g, b, a read from it:
 * its alpha, or else its grey *)
val coverage : Memimage.t -> int * int * int * int -> int

(* [general dst r src sr mask mr op] draws r of dst from sr of src
 * through mr of mask. The three rectangles are already clipped and of
 * one size (by Memdraw's drawclip). *)
val general : Memimage.t -> Memimage.rect -> Memimage.t -> Memimage.rect -> Memimage.t -> Memimage.rect -> int -> unit
