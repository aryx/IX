(* A pixel's format (draw.h's chan). It lists the pixel's channels from
 * its top bits down. Each channel has a type (red, green, blue, grey,
 * alpha, a colour map index, or ignored) and a number of bits: RGB16
 * is r5 g6 b5, and GREY1 is k1. A 32-bit chan is carried as its two
 * 16-bit halves, because a Pi1 int has 31 bits. This module also has
 * the conversions every drawing uses: a channel's bits widened to 8
 * (by replicating them, as memdraw's replbit does), the NTSC grey of a
 * colour (RGB2K), and the default colour map.
 *
 *     an RGB16 pixel, 16 bits:   r r r r r g g g g g g b b b b b
 *     pure red is 0xf800; a red of 5 bits, 10000, widened to 8 has
 *     its bits written again beside themselves: 10000100, 132
 *     (and 11111 gives 255, 00000 gives 0: the whole range, where
 *     three zeros appended would stop at 248)
 *
 *     a colour's grey is (156763 r + 307758 g + 59769 b) / 2^19, that
 *     is 0.299 r + 0.587 g + 0.114 b in integers: pure red is 76
 *
 * Every drawing goes through these. Memdraw widens each pixel it reads
 * to 8 bits a channel, composes, and narrows the result to the
 * destination's format, so any image can be drawn on any other. On
 * the Pi, the screen is RGB16 and the cursor's mask is GREY1.
 *
 * design:
 * The format is a value, not a type. An image says what its pixels
 * are made of by a small list that a program can read and build
 * (r5g6b5, k1, r8g8b8a8), and one loop serves them all. Green has six
 * bits, and the grey's weights favour it, for the same reason: the eye
 * tells greens apart best. *)

type t = {
  hi : int;
  lo : int;
  (* the channels, the top one first: each is a type, a number of bits,
   * and a shift from the pixel's low bit *)
  chans : (int * int * int) list;
  depth : int;
  grey : bool;
  alpha : bool;
  cmap : bool;
}

(* the channel types *)
val cred : int
val cgreen : int
val cblue : int
val cgrey : int
val calpha : int
val cmapped : int
val cignore : int

(* [make hi lo] is None when hi and lo are not a chan (when chantodepth
 * gives 0) *)
val make : int -> int -> t option

(* chantostr: the name, such as "r5g6b5" or "k1" *)
val name : t -> string

(* [repl n v] widens v's n bits to 8, by repeating their pattern *)
val repl : int -> int -> int

(* the grey of r, g, b *)
val rgb2k : int -> int -> int -> int

(* the default colour map: [cmap2rgb] gives an index's r, g, b, and
 * [rgb2cmap] the index nearest to r, g, b *)
val cmap2rgb : int -> int * int * int
val rgb2cmap : int -> int -> int -> int
