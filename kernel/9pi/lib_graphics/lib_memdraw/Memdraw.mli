(* memimagedraw: dst's rectangle r, from src at sp through mask at mp,
 * composed by op (draw.h's Porter-Duff: SoverD 11, S 10, ...). Clipped
 * as memdraw's drawclip clips (dst's rectangle and clip, src's and
 * mask's, a repl image tiling the plane), then one general loop: each
 * pixel's channels widened to 8 bits, composed with memdraw's
 * arithmetic (MUL's rounding, its formulas per op: alphadraw.c's
 * alphacalc functions), narrowed into dst's chan. memdraw's faster paths give
 * the same pixels, but for its packed 32-bit one (two pixels' bytes
 * rounded apart), not reproduced. *)

type rect = Memimage.rect

(* hwdraw's hook: a drawing on the screen's memory, its rectangle there
 * (Swcursor's avoid) *)
val hwdraw : (rect -> unit) ref

val draw : Memimage.t -> rect -> Memimage.t -> int * int -> Memimage.t -> int * int -> int -> unit

(* the faster paths (a fill, a copy, a character) on; off, the general
 * loop for everything *)
val fast : bool ref

(* drawreplxy: x in [min, max), the plane tiled *)
val replxy : int -> int -> int -> int
