(* The pixels, as mini-9pi's OCaml sees them: images, the screen on the
 * framebuffer, drawing, strings in the default font, windows. Two
 * implementations (the Makefile's PIXEL): c/, principia's libmemdraw,
 * libmemlayer and libdraw's geometry in C (plan_9pi.md, decision 4:
 * draw9.c, drawglue.c), and ocaml/ (stage F). *)

type image

(* the hooks the pixels call: a drawing on the screen's memory
 * (memdraw's hwdraw: Swcursor's avoid, its rectangle), a window's part
 * to redraw (drawrefresh: Devdraw's refresh, its Refx's number and
 * rectangle) *)
val on_screen : (int * int * int * int -> unit) ref
val on_refresh : (int * int * int * int * int -> unit) ref

(* [init pa w h]: the screen, RGB16, on the framebuffer at physical
 * address pa; false when it cannot be made *)
val init : int -> int -> int -> bool

val screen : unit -> image
val white : unit -> image
val black : unit -> image
val opaque : unit -> image

(* a 1x1 replicated RGB16 colour, its two bytes; one freed *)
val color16 : int -> int -> image
val free : image -> unit

(* [draw dst (x0, y0, x1, y1) src (sx, sy, mx, my) mask] *)
val draw : image -> int * int * int * int -> image -> int * int * int * int -> image -> unit

(* [string dst (x, y) src s]: the default font's s, its end's x *)
val string : image -> int * int -> image -> string -> int

val fontheight : unit -> int
val stringwidth : string -> int

(* [alloc (x0, y0, x1, y1) chan]: a new image, transparent; chan 0 the
 * screen's *)
val alloc : int * int * int * int -> int -> image
(* [load img bytes]: its pixels, row after row; the bytes used *)
val load : image -> string -> int

(* the chans (draw.h's GREY1, GREY8) *)
val grey1 : int
val grey8 : int

(* The draw device's (Devdraw): its messages' ints in an int array, as
 * draw9.c's d9_* take them; a 32-bit chan or colour as two 16-bit
 * halves *)

(* a null image (an allocation failed) *)
val isnil : image -> bool
(* makescreenimage's: another image on the screen's memory *)
val screenimage : unit -> image
(* 'b': [| r[4] chan[2] repl clipr[4] value[2] |] *)
val allocimage : int array -> image
val setrepl : image -> unit
(* [| clipr[4] |] *)
val setclipr : image -> int array -> unit
(* its chan's name, [| chan[2] repl r[4] clipr[4] depth layer |] *)
val info : image -> string * int array
(* [drawop dst src mask [| r[4] p[2] q[2] op |]] *)
val drawop : image -> image -> image -> int array -> unit
(* [| p0[2] p1[2] end0 end1 radius sp[2] op |] *)
val line : image -> image -> int array -> unit
(* [| end0 end1 radius sp[2] op fill n pts[2n] |]: -1 no memory *)
val poly : image -> image -> int array -> int
(* [| c[2] a b thick sp[2] op arc alpha phi |] *)
val ellipse : image -> image -> int array -> unit
(* [memload dst [| r[4] compressed |] data]: the bytes used, -1 bad *)
val memload : image -> int array -> string -> int
(* [unload img [| r[4] |]]: its pixels *)
val unload : image -> int array -> string

(* Layers: a screen (Memscreen: its image, its fill), windows on it *)
type memscreen
val memscreen : image -> image -> memscreen
val freememscreen : memscreen -> unit
(* its image's chan, its halves *)
val memscreenchan : memscreen -> int * int
(* 'b' on a screen: [| r[4] refresh clipr[4] value[2] |], a null image
 * when it fails *)
val lalloc : memscreen -> int array -> image
(* its refresh's pointer: a Refx's number (Devdraw's), 0 none *)
val lsetrefresh : image -> int -> unit
(* [| refx screenr[4] onscreen |] *)
val layerinfo : image -> int array
(* [lfree l delete]: memldelete (its screen still good) or memlfree *)
val lfree : image -> bool -> unit
(* [ltofront windows front]: 0, -1 not windows, -2 not on one screen *)
val ltofront : image array -> bool -> int
(* [| log[2] scr[2] |]: -1 failed, 0 no move, 1 moved *)
val lorigin : image -> int array -> int
