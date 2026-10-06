(* A pixel's format (draw.h's chan): its channels from the pixel's top
 * bits down, each a type (red, green, blue, grey, alpha, a colour map
 * index, ignored) and a number of bits (RGB16: r5 g6 b5; GREY1: k1).
 * A 32-bit chan is carried as its two 16-bit halves (a Pi1 int has 31
 * bits). And the conversions every drawing uses: a channel's bits
 * widened to 8 (replicated, memdraw's replbit), the NTSC grey of a
 * colour (RGB2K), the default colour map. *)

type t = {
  hi : int;
  lo : int;
  (* the channels, top first: type, bits, shift from the pixel's low bit *)
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

(* [make hi lo]: None when not a chan (chantodepth's 0) *)
val make : int -> int -> t option

(* chantostr: "r5g6b5", "k1" *)
val name : t -> string

(* [repl n v]: n bits made 8 (their pattern repeated) *)
val repl : int -> int -> int

(* the grey of r, g, b *)
val rgb2k : int -> int -> int -> int

(* the default colour map: an index's r, g, b; the index nearest r, g, b *)
val cmap2rgb : int -> int * int * int
val rgb2cmap : int -> int -> int -> int
