(* memimagedraw: dst's rectangle r, from src at sp through mask at mp,
 * composed by op (draw.h's Porter-Duff: SoverD 11, S 10, ...). Clipped
 * as memdraw's drawclip clips (dst's rectangle and clip, src's and
 * mask's, a repl image tiling the plane), then one general loop: each
 * pixel's channels widened to 8 bits, composed with memdraw's
 * arithmetic (MUL's rounding, its formulas per op: alphadraw.c's
 * alphacalc functions), narrowed into dst's chan. memdraw's faster paths give
 * the same pixels, but for its packed 32-bit one (two pixels' bytes
 * rounded apart), not reproduced.
 *
 * One operation is the whole of Plan 9's graphics: put the source
 * on the destination, through the mask. The mask says how much of
 * each pixel (its alpha, or its grey if it has no alpha); the
 * source says what colour; the operator, how the two combine with
 * what is there. For the usual one, S over D:
 *
 *     dst = src * m + dst * (1 - alpha(src) * m)
 *
 *     a red pixel (255, 0, 0), opaque, through a mask of 128,
 *     over a blue one (0, 0, 255):
 *       MUL(128, 255) + MUL(127, 0)   = 128    red
 *       MUL(128, 0)   + MUL(127, 0)   = 0      green
 *       MUL(128, 0)   + MUL(127, 255) = 127    blue
 *     where 127 is 255 - MUL(255, 128), and MUL(x, y) is x * y / 255
 *     rounded, by an add and two shifts: t = x*y + 128; (t + t/256)/256
 *
 * Everything else is this with particular images. A filled
 * rectangle: the source is one pixel that tiles the plane (repl),
 * the mask is opaque. Text: the source is the ink, a pixel; the mask
 * is the font's image, a character's rectangle of it (Memfont), so
 * the letter's shape is where ink goes. A window copied to the
 * screen: the source is the window, the mask opaque, the operator S
 * (Memlayer). A cursor: an image through its own mask (Swcursor).
 *
 * Above it: Kdraw for the kernel, Devdraw's d and s messages for
 * programs. The same library in a program's own memory is how a
 * program draws off the screen.
 *
 * cs-history:
 * The algebra is Thomas Porter's and Tom Duff's (Lucasfilm, 1984):
 * a pixel carries, with its colour, how much of it is covered
 * (alpha), and twelve operators say every way two such pictures can
 * be combined; over is the one films are made of. Duff then came to
 * Bell Labs, where he wrote rc (shell's CLI). The names here (SoverD,
 * SinD, DatopS...) are the paper's.
 *
 * evolution:
 * Before it there was bitblt (Dan Ingalls, for Smalltalk at Xerox
 * PARC, in the 1970s): copy a rectangle of bits onto another,
 * combined by one of the sixteen functions of two bits (and, or,
 * xor...). It suits one bit a pixel, and is what the Blit and Plan
 * 9's first window system used; xor drew a cursor and erased it
 * again. With colour a function of bits means little, and Plan 9
 * replaced all sixteen with the composition above (the draw device
 * and library of the third edition).
 *
 * References: Thomas Porter and Tom Duff, "Compositing Digital
 * Images" (SIGGRAPH 1984): short, and all of this. draw(2) and
 * memdraw(2) in the Plan 9 manual. Rob Pike, Bart Locanthi and John
 * Reiser, "Hardware/Software Trade-offs for Bitmap Graphics on the
 * Blit" (Software: Practice and Experience, 1985), for bitblt made
 * fast. principia's Graphics.nw. *)

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
