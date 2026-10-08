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

(* the faster paths (a fill, a copy, a picture of 32 bits to 16, a character) on; off, the general
 * loop for everything *)
val fast : bool ref
(* a narrow fill's rows written by the machine's C (mem_rows), two bytes
 * a store; off: by Memdraw's own loops, a byte a store *)
val fast_rows : bool ref

(* A shape in one opaque colour, by its runs: [solid dst src op] is how
 * to write one ([x0, x1) of row y, clipped to dst), when dst and src
 * allow it (dst no window, src one opaque pixel repeated, op S or
 * SoverD, the faster paths on); None: each run a [draw]. Round the
 * runs, for a dst on the screen: [solid_start dst r] (r, all that will
 * be drawn: the cursor out of it) and [solid_done dst r] (r to the
 * framebuffer). *)
val solid : Memimage.t -> Memimage.t -> int -> (int -> int -> int -> unit) option
val solid_start : Memimage.t -> rect -> unit
val solid_done : Memimage.t -> rect -> unit

(* drawreplxy: x in [min, max), the plane tiled *)
val replxy : int -> int -> int -> int
