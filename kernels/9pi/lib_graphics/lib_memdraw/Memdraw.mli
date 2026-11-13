(* memimagedraw draws dst's rectangle r from src at sp, through mask at
 * mp, composed by op (draw.h's Porter-Duff operators: SoverD is 11, S
 * is 10, ...). It clips as memdraw's drawclip clips (by dst's rectangle
 * and clip, by src's and mask's, with a repl image tiling the plane),
 * then runs one general loop. Each pixel's channels are widened to 8
 * bits, composed with memdraw's arithmetic (MUL's rounding, and its
 * formulas for each op: alphadraw.c's alphacalc functions), and
 * narrowed into dst's chan. memdraw's faster paths give the same
 * pixels, except its packed 32-bit one (which rounds two pixels' bytes
 * apart), and that one is not reproduced.
 *
 * One operation is the whole of Plan 9's graphics: put the source on
 * the destination, through the mask. The mask says how much of each
 * pixel to cover (its alpha, or its grey if it has no alpha); the
 * source says what colour; and the operator says how the two combine
 * with what is there. For the usual operator, S over D:
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
 * Everything else is this operation with particular images:
 * - a filled rectangle: the source is one pixel that tiles the plane
 *   (repl), and the mask is opaque;
 * - text: the source is the ink, a pixel, and the mask is the font's
 *   image, a character's rectangle of it (Memfont), so the letter's
 *   shape is where the ink goes;
 * - a window copied to the screen: the source is the window, the mask
 *   is opaque, and the operator is S (Memlayer);
 * - a cursor: an image drawn through its own mask (Swcursor).
 *
 * Above this module are Kdraw for the kernel, and Devdraw's d and s
 * messages for programs. A program draws off the screen by using the
 * same library in its own memory.
 *
 * cs-history:
 * The algebra is Thomas Porter's and Tom Duff's (Lucasfilm, 1984). A
 * pixel carries, with its colour, how much of it is covered (alpha),
 * and twelve operators say every way two such pictures can be
 * combined; over is the one films are made of. Duff then came to Bell
 * Labs, where he wrote rc (shell's CLI). The names here (SoverD, SinD,
 * DatopS...) are the paper's.
 *
 * evolution:
 * Before it there was bitblt (Dan Ingalls, for Smalltalk at Xerox
 * PARC, in the 1970s). It copies a rectangle of bits onto another,
 * combined by one of the sixteen functions of two bits (and, or,
 * xor...). It suits one bit a pixel, and it is what the Blit and Plan
 * 9's first window system used; xor drew a cursor and erased it again.
 * With colour, a function of bits means little, and Plan 9 replaced
 * all sixteen with the composition above (in the draw device and
 * library of the third edition).
 *
 * References: Thomas Porter and Tom Duff, "Compositing Digital
 * Images" (SIGGRAPH 1984), which is short and has all of this. draw(2)
 * and memdraw(2) in the Plan 9 manual. Rob Pike, Bart Locanthi and
 * John Reiser, "Hardware/Software Trade-offs for Bitmap Graphics on
 * the Blit" (Software: Practice and Experience, 1985), on making bitblt
 * fast. principia's Graphics.nw. *)

type rect = Memimage.rect

(* hwdraw's hook, called for a drawing on the screen's memory with its
 * rectangle there (used by Swcursor's avoid) *)
val hwdraw : (rect -> unit) ref

val draw : Memimage.t -> rect -> Memimage.t -> int * int -> Memimage.t -> int * int -> int -> unit

(* when on, the faster paths are used (a fill, a copy, a picture of 32
 * bits to 16, a character); when off, the general loop does everything *)
val fast : bool ref
(* when on, a narrow fill's rows are written by the machine's C
 * (mem_rows), two bytes a store; when off, by Memdraw's own loops, a
 * byte a store *)
val fast_rows : bool ref

(* when on, an image of one bit a pixel through a mask of one bit (the
 * cursor) is drawn by a loop of its own; when off, by the general
 * loop *)
val fast_bits : bool ref

(* A shape in one opaque colour, drawn by its runs. [solid dst src op]
 * gives the function that writes one run ([x0, x1) of row y, clipped
 * to dst), when dst and src allow it: dst is not a window, src is one
 * opaque pixel repeated, op is S or SoverD, and the faster paths are
 * on. When it is None, each run is a [draw]. For a dst on the screen,
 * the runs are put between [solid_start dst r], where r is all that
 * will be drawn (the cursor is taken out of it), and [solid_done dst r]
 * (which writes r to the framebuffer). *)
val solid : Memimage.t -> Memimage.t -> int -> (int -> int -> int -> unit) option
val solid_start : Memimage.t -> rect -> unit
val solid_done : Memimage.t -> rect -> unit

(* drawreplxy: x brought into [min, max), with the plane tiled *)
val replxy : int -> int -> int -> int

(* when on, an opaque colour through a mask of a byte a pixel (a
 * smoothed letter) is drawn by a loop of its own; when off, by the
 * general loop *)
val fast_grey : bool ref

(* ix: [scale dst r src sp k] draws src from sp into dst's r k times
 * larger, each pixel k by k, with no blending. It is the draw device's
 * 'z', an extension of Plan 9's protocol
 * (docs/plans/done/plan_playground_framebuffer.md, F5). It is for a
 * game's 320 by 200 shown on the whole screen: the program gives its
 * small picture, and the kernel's one loop writes the large one,
 * instead of the program writing it k times larger and sending all of
 * it through the device's copies. It works only between images of one
 * chan with whole bytes for a pixel, with src neither repeated nor
 * sharing dst's memory; otherwise it returns false. *)
val scale : Memimage.t -> rect -> Memimage.t -> int * int -> int -> bool

(* ix: [shrink dst r src sp k] draws src from sp into dst's r k times
 * smaller: each pixel of dst is the one of src at k times its offset
 * (the nearest, with no blending). It makes a window's picture into a
 * thumbnail, for Expose (plan_desktop.md), and it is the draw device's
 * 'Z', scale's other way. It takes the same images as scale and clips
 * as scale does; otherwise it returns false. In OCaml it does a copy
 * for each pixel: a screen's worth takes a fraction of a second on a
 * Pi 1, for a picture looked at twice a second. *)
val shrink : Memimage.t -> rect -> Memimage.t -> int * int -> int -> bool
