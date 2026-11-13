(* An image (memdraw's Memimage) is a rectangle of pixels of a chan,
 * with its clip and whether it tiles the plane (repl). Its bytes are in
 * memdraw's layout, as the draw protocol's loads and reads carry them:
 * rows of 32-bit words, with a pixel's bits where its absolute x puts
 * them, bit 7 first for a small depth. Images may share their memory.
 * The screen's memory (the framebuffer's shadow, written through to the
 * framebuffer by [flush]) is shared by Devdraw's screen image and the
 * kernel's. *)

type rect = int * int * int * int

type data = { mutable bytes : Bytes.t; onscreen : bool; keep : bool }

type t = {
  data : data;
  mutable r : rect;
  mutable clipr : rect;
  mutable repl : bool;
  chan : Memchan.t;
  (* the bytes of a row; the layout's origin (r.min when the image was
   * made: a window's r moves, but its pixels do not, see memlorigin);
   * and the byte of its x in a row *)
  bwidth : int;
  org : int * int;
  xbase : int;
  (* the window this image is, if it is one (Memlayer) *)
  mutable layer : layer option;
}

(* a window: its screen, and where it is on that screen *)
and layer = { lscr : lscreen; mutable screenr : rect }

(* a screen that windows are on: its image, its fill, and its windows
 * (the front one first) *)
and lscreen = { simage : t; sfill : t; mutable wins : t list }

(* rectclip: the intersection, or None when it is empty *)
val clip : rect -> rect -> rect option
val inside : rect -> rect -> bool

(* [alloc r chan] makes a zeroed image; [alloc_on data r chan] makes
 * one on data (the screen's memory) *)
val alloc : rect -> Memchan.t -> t
val alloc_on : data -> rect -> Memchan.t -> t
(* an image whose bytes are in the images' memory, outside OCaml's heap
 * (Machine.Imag, principia's imagmem; they are in the heap when there
 * is no room). It is used for the draw device's own images, a
 * program's image, a window, and the screen's copy. The collector does
 * not see these bytes, a copy between two such images is done with the
 * kernel's lock given back, and they are freed by [free] ([free] does
 * nothing for an image of [alloc]'s, or for the screen's) *)
val alloc_out : rect -> Memchan.t -> t
val free : t -> unit
(* whether a flush writes its rows by one call to the machine (true),
 * or by one call for each row *)
val flush_rows : bool ref

(* the framebuffer that the screen's data shadows: its physical
 * address and its pitch *)
val framebuffer : (int * int) ref
(* how the framebuffer's memory is written: [!to_screen pa s off n]
 * writes s's n bytes from off to the physical address pa. It is the
 * one thing of the machine that this library needs, and so the caller
 * gives it (the kernel's Kdraw writes the memory itself; a program's
 * could write to a file) *)
val to_screen : (int -> string -> int -> int -> unit) ref

(* writes the rows of r to the framebuffer, when the image is on the
 * screen *)
val flush : t -> rect -> unit

(* [layout] gives a point in the layout's coordinates (which differ
 * once a window's r has moved), and [byteaddr] a pixel's byte offset *)
val layout : t -> int -> int -> int * int
val byteaddr : t -> int -> int -> int

(* [read img x y] gives the pixel's channels, 8 bits each: r, g, b, a
 * (a is 255 without alpha). For a grey image, r, g and b are the grey;
 * for a mapped one, they are the colour of the map's entry. *)
val read : t -> int -> int -> int * int * int * int

(* [write img x y (r, g, b, a) k] writes the pixel from 8-bit channels
 * (k is the grey, for a grey image) *)
val write : t -> int -> int -> int * int * int * int -> int -> unit

(* a pixel's bytes (depth/8 of them, for a depth >= 8) from 8-bit
 * channels and the grey *)
val pattern : t -> int * int * int * int -> int -> string
(* when on, the screen's 16-bit pattern is computed directly; when off,
 * it is made by an image of one pixel *)
val fast_pattern : bool ref
(* when on, a pixel of r8g8b8a8 is read by its bytes; when off, it is
 * read by its channels, as any other *)
val fast_read : bool ref

(* [repeat pat len] repeats pat's bytes over len bytes (a fill's row),
 * by doubling blits. It uses no division (the Pi1 has no divide
 * instruction), and log2 of the repetitions memmoves. *)
val repeat : string -> int -> string

(* memfillcolor: sets every pixel to an rgba (given as its halves: r g,
 * then b a) *)
val fill : t -> int -> int -> unit

(* loadmemimage and cloadmemimage load r's rows from the bytes, and
 * return how many bytes were used (-1 when they are bad);
 * unloadmemimage returns r's rows *)
val load : t -> rect -> string -> int
(* when on, a row of whole bytes is loaded by one blit; when off, a
 * byte at a time *)
val fast_load : bool ref
val cload : t -> rect -> string -> int
val unload : t -> rect -> string
