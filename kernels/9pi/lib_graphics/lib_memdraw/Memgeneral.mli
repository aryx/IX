(* The general loop of memdraw, apart: every pixel of the source and of
 * the mask read, composed with the destination's by the operator,
 * written (alphadraw.c's, without its buffers). Memdraw calls it when
 * none of its faster paths has the case.
 *
 *     dst(x, y) <- fs * src + fd * dst      (each channel, MUL's rounding)
 *     SoverD:  fs = the mask's coverage, fd = 255 - MUL(src's alpha, coverage)
 *
 * design: a file of its own because a machine's host can run it too.
 * It reads and writes an image's bytes through Memimage only, and an
 * image's bytes may be anyone's: mini-qemu's board, asked by the kernel
 * built for a web page (Memdraw's draw there, Hostdraw on the board's
 * side), runs this same file compiled for the host on the images where
 * they are in the board's memory. The pixels are then the same by
 * construction, and the loop is the host's and not the emulator's: a
 * menu of rio's was 20 million instructions here.
 *
 * Pike, "draw - screen graphics" (Plan 9 manual, draw(2)); Porter and
 * Duff, "Compositing Digital Images" (SIGGRAPH 1984). *)

(* MUL: x*y/255, memdraw's rounding *)
val mul : int -> int -> int

(* the ops (draw.h's Drawop) *)
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

(* a mask's coverage of a pixel (its r, g, b, a read): its alpha, or
 * else its grey *)
val coverage : Memimage.t -> int * int * int * int -> int

(* [general dst r src sr mask mr op]: r of dst from sr of src through
 * mr of mask, the three already clipped and of one size (Memdraw's
 * drawclip) *)
val general : Memimage.t -> Memimage.rect -> Memimage.t -> Memimage.rect -> Memimage.t -> Memimage.rect -> int -> unit
