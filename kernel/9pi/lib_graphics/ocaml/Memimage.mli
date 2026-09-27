(* An image (memdraw's Memimage): a rectangle of pixels of a chan, its
 * clip, whether it tiles the plane (repl); its bytes in memdraw's
 * layout, as the draw protocol's loads and reads carry them (rows of
 * 32-bit words, a pixel's bits where its absolute x puts them: bit
 * 7 first for a small depth). Images may share their memory: the
 * screen's (the framebuffer's shadow, written through to it: [flush])
 * is Devdraw's screen image's and the kernel's. *)

type rect = int * int * int * int

type data = { mutable bytes : string; onscreen : bool }

type t = {
  data : data;
  mutable r : rect;
  mutable clipr : rect;
  mutable repl : bool;
  chan : Memchan.t;
  (* bytes a row; the layout's origin (r.min when made: a window's r
   * moves, its pixels do not: memlorigin), its x's byte in a row *)
  bwidth : int;
  org : int * int;
  xbase : int;
  (* a window's (Memlayer) *)
  mutable layer : layer option;
}

(* a window: its screen, where it is there *)
and layer = { lscr : lscreen; mutable screenr : rect }

(* a screen windows are on: its image, its fill, its windows (the
 * front first) *)
and lscreen = { simage : t; sfill : t; mutable wins : t list }

(* rectclip: the intersection, None when empty *)
val clip : rect -> rect -> rect option
val inside : rect -> rect -> bool

(* [alloc r chan]: zeroed; [alloc_on data r chan] on data (the
 * screen's memory) *)
val alloc : rect -> Memchan.t -> t
val alloc_on : data -> rect -> Memchan.t -> t

(* the framebuffer (its physical address, its pitch) the screen's
 * data shadows *)
val framebuffer : (int * int) ref

(* the rows of r written to the framebuffer, when on the screen *)
val flush : t -> rect -> unit

(* a point in the layout's coordinates (a window's r moved), a pixel's
 * byte offset *)
val layout : t -> int -> int -> int * int
val byteaddr : t -> int -> int -> int

(* [read img x y]: the pixel's channels, 8 bits each: r, g, b, a (255
 * without alpha); a grey image's grey its r, g, b; a mapped one's
 * colour *)
val read : t -> int -> int -> int * int * int * int

(* [write img x y (r, g, b, a) k]: the pixel from 8-bit channels (k the
 * grey, for a grey image) *)
val write : t -> int -> int -> int * int * int * int -> int -> unit

(* a pixel's bytes (depth >= 8: depth/8 of them) from 8-bit channels
 * and the grey *)
val pattern : t -> int * int * int * int -> int -> string

(* [repeat pat len]: pat's bytes repeated over len bytes (a fill's
 * row), by doubling blits: no division (the Pi1 has no divide
 * instruction), log2 of the repetitions memmoves *)
val repeat : string -> int -> string

(* memfillcolor: every pixel an rgba (its halves: r g, b a) *)
val fill : t -> int -> int -> unit

(* loadmemimage, cloadmemimage: r's rows from the bytes; how many
 * bytes used (-1: bad); unloadmemimage: r's rows *)
val load : t -> rect -> string -> int
val cload : t -> rect -> string -> int
val unload : t -> rect -> string
