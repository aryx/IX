(* The pixels, as mini-9pi's OCaml sees them: images, the screen on the
 * framebuffer, drawing, strings in the default font, and windows. There
 * are two implementations (the Makefile's PIXEL):
 * - c/ is principia's libmemdraw, libmemlayer and libdraw's geometry,
 *   in C (plan_9pi.md, decision 4: draw9.c, drawglue.c);
 * - ocaml/ (stage F) is built over lib_memdraw (images in memory,
 *   drawing, the font) and lib_memlayer (windows that cover each other,
 *   shapes). These are principia's two libraries in OCaml, and, as in
 *   principia, they name nothing of the kernel's (a program could draw
 *   in its own memory with them).
 * This module is the kernel's part: the screen on the framebuffer, and
 * what Devdraw, Swconsole and Swcursor ask for. (It is Kdraw, not Draw,
 * because a program's Draw is the one in ../../../lib_graphics.) *)

type image

(* the hooks the pixels call. [on_screen] is called for a drawing on
 * the screen's memory, with its rectangle (memdraw's hwdraw, used by
 * Swcursor's avoid). [on_refresh] is called for a window's part to
 * redraw, with its Refx's number and its rectangle (drawrefresh, used
 * by Devdraw's refresh). *)
val on_screen : (int * int * int * int -> unit) ref
val on_refresh : (int * int * int * int * int -> unit) ref

(* [init pa w h] makes the screen, RGB16, on the framebuffer at the
 * physical address pa; it returns false when the screen cannot be
 * made *)
val init : int -> int -> int -> bool
(* whether these pixels of the screen are being written now by a copy
 * that gave the kernel's lock back (with the OCaml pixels, by
 * Machine.Imag) *)
val busy : int * int * int * int -> bool

val screen : unit -> image
val white : unit -> image
val black : unit -> image
val opaque : unit -> image

(* [color16] makes a 1x1 replicated RGB16 colour from its two bytes;
 * [free] frees an image *)
val color16 : int -> int -> image
val free : image -> unit

(* [draw dst (x0, y0, x1, y1) src (sx, sy, mx, my) mask] *)
val draw : image -> int * int * int * int -> image -> int * int * int * int -> image -> unit

(* [string dst (x, y) src s] draws s in the default font, and returns
 * the x of its end *)
val string : image -> int * int -> image -> string -> int

val fontheight : unit -> int
val stringwidth : string -> int

(* [alloc (x0, y0, x1, y1) chan] makes a new, transparent image; a chan
 * of 0 means the screen's *)
val alloc : int * int * int * int -> int -> image
(* [load img bytes] loads its pixels, row after row, and returns the
 * number of bytes used *)
val load : image -> string -> int

(* the chans GREY1 and GREY8 of draw.h *)
val grey1 : int
val grey8 : int

(* What the draw device (Devdraw) uses. Its messages' ints are given in
 * an int array, as draw9.c's d9_* functions take them, and a 32-bit
 * chan or colour is given as two 16-bit halves. *)

(* whether an image is the null one (an allocation failed) *)
val isnil : image -> bool
(* as makescreenimage does: another image on the screen's memory *)
val screenimage : unit -> image
(* 'b': [| r[4] chan[2] repl clipr[4] value[2] |] *)
val allocimage : int array -> image
val setrepl : image -> unit
(* [| clipr[4] |] *)
val setclipr : image -> int array -> unit
(* its chan's name, and [| chan[2] repl r[4] clipr[4] depth layer |] *)
val info : image -> string * int array
(* [drawop dst src mask [| r[4] p[2] q[2] op |]] *)
val drawop : image -> image -> image -> int array -> unit
(* [| p0[2] p1[2] end0 end1 radius sp[2] op |] *)
val line : image -> image -> int array -> unit
(* [| end0 end1 radius sp[2] op fill n pts[2n] |]; -1 means no memory *)
val poly : image -> image -> int array -> int
(* [| c[2] a b thick sp[2] op arc alpha phi |] *)
val ellipse : image -> image -> int array -> unit
(* [memload dst [| r[4] compressed |] data] returns the bytes used, or
 * -1 when they are bad *)
val memload : image -> int array -> string -> int
(* ix: [scale dst src [| r[4] sp[2] k |]] draws src k times larger,
 * each pixel k by k (Memdraw.scale; the draw device's 'z'). It returns
 * false when it cannot: for another chan, or with the C pixels
 * (PIXEL=c), which have no scale. *)
val scale : image -> image -> int array -> bool
(* ix: [shrink dst src [| r[4] sp[2] k |]] draws src k times smaller
 * (Memdraw.shrink; the draw device's 'Z'). It returns false in the same
 * cases as scale. *)
val shrink : image -> image -> int array -> bool
(* [unload img [| r[4] |]] returns its pixels *)
val unload : image -> int array -> string

(* Layers: a screen (a Memscreen, which has an image and a fill), and
 * windows on it *)
type memscreen
val memscreen : image -> image -> memscreen
val freememscreen : memscreen -> unit
(* the chan of the screen's image, as its halves *)
val memscreenchan : memscreen -> int * int
(* 'b' on a screen: [| r[4] refresh clipr[4] value[2] |]. It returns a
 * null image when it fails. *)
val lalloc : memscreen -> int array -> image
(* sets the window's refresh pointer: a Refx's number (Devdraw's), or 0
 * for none *)
val lsetrefresh : image -> int -> unit
(* [| refx screenr[4] onscreen |] *)
val layerinfo : image -> int array
(* [lfree l delete] calls memldelete (when the window's screen is still
 * good) or memlfree *)
val lfree : image -> bool -> unit
(* [ltofront windows front] returns 0, or -1 when they are not windows,
 * or -2 when they are not on one screen *)
val ltofront : image array -> bool -> int
(* [| log[2] scr[2] |]: it returns -1 when it failed, 0 when the window
 * did not move, and 1 when it moved *)
val lorigin : image -> int array -> int
