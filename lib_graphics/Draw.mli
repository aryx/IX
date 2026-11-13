(* Drawing (Plan 9's libdraw; xix's lib_graphics/draw). Each function
 * sends a message of the draw device, on a Display's images.
 *
 * One operation, [draw], does nearly all of it. It takes three images
 * and lays them on one another at a rectangle r of the first:
 *
 *        src   what to paint      mask   where, and how much
 *       +---------+              +---------+
 *       |/////////|              |   ##    |
 *       |/////////|              |  #  #   |
 *       +---------+              +---------+
 *              \                    /
 *               v                  v
 *          dst: for each pixel of r,
 *               dst = src * mask + dst * (1 - mask)
 *
 * The mask's value goes from 0 (dst is left as it is) to 1 (src
 * replaces it). It is a bit or a byte for each pixel, or the alpha of
 * an image that has one. What the three images are says what the
 * operation is:
 *
 *     src            mask                 what it does
 *     a colour       none                 fills a rectangle ([fill])
 *     an image       none                 copies: shows a picture, or
 *                                         puts back what a menu
 *                                         covered (Menu)
 *     a colour       a font's image       draws a character in that
 *                                         colour (Font.string)
 *     a colour       a grey image         draws a shape with smooth
 *                                         edges, or a shadow
 *     an image       a colour, half       draws the image so that what
 *                    opaque               is under it shows through
 *
 * A colour is an image like the others: one pixel that repeats over the
 * plane (Display.color), so no function takes a colour and an image
 * separately. And no mask means the white one (Display.opaque).
 *
 * The shapes ([line], [poly], [ellipse]) are messages too. The kernel
 * finds their pixels (mini-9pi's Memshape) and paints src there, with
 * the shape in place of the mask. A program that would rather find the
 * pixels itself, with smooth edges, draws in its own memory
 * (Framebuffer, with Line, Fill, Circle and Stroke) and gives the rows
 * to an image (Display.load). This is what lib_playground's games do.
 *
 * A polygon's points are sent short: each coordinate is sent as its
 * difference from the one before. It takes a byte when the difference
 * is from -64 to 63, and otherwise three bytes with the whole
 * coordinate (the first byte's high bit says which). So a curve made of
 * many small steps takes two bytes a point.
 *
 * cs-history:
 * Bitblt came before it. Dan Ingalls's BitBlt (Xerox PARC, 1975, for
 * Smalltalk on the Alto) copied a rectangle of bits onto another
 * through a boolean function of the two, one of sixteen: replace, or,
 * and, and the exclusive or, which draws a cursor or a rubber band and
 * takes it away when done twice. Pike's bitblt on the Blit and in Plan
 * 9's first editions was that operation. It has no meaning on pixels
 * that are colours: the exclusive or of two reds is no colour anyone
 * chose. A pixel had been given a fourth number, alpha, which says how
 * much of the pixel the colour covers (Ed Catmull and Alvy Ray Smith,
 * New York Institute of Technology, 1977). Thomas Porter and Tom Duff
 * (Lucasfilm, 1984) gave twelve ways to combine two such pictures, of
 * which "over" is paint and "in" is a stencil, and they kept the
 * colours multiplied by their alpha. Plan 9's draw (2000) makes those
 * two the one operation, dst = (src in mask) over dst, in place of the
 * sixteen functions. The other operators came later, as a number in a
 * message of its own (the kernel's Memdraw has them).
 *
 * others:
 * X11's first protocol (1987) has the sixteen functions, in a graphics
 * context kept by the server, and separate requests for a copy, a
 * filled rectangle and a string of characters. Its Render extension
 * (Keith Packard, 2000) added compositing as one request, Composite,
 * which takes an operator and three pictures: a source, a mask and a
 * destination, as here, and it said where it took them from. The
 * canvas of a web page, PDF's transparency (Pdf_canvas) and a graphics
 * card's blending are the same "over".
 *
 * design:
 * There is one general operation where there were several. The cases
 * that must be fast (a colour with no mask, a copy between images of
 * the same format) are found by the implementer, who looks at the
 * arguments; the caller does not choose them among several functions.
 * So the interface stays one line, and a combination nobody thought of
 * (a picture through another picture's alpha) works the first time.
 *
 * References: draw(2) of Plan 9's manual; Thomas Porter and Tom Duff,
 * "Compositing Digital Images" (SIGGRAPH 1984), on the operators and
 * why colours are kept multiplied by their alpha; Rob Pike, Bart
 * Locanthi and John Reiser, "Hardware/Software Trade-offs for Bitmap
 * Graphics on the Blit" (Software: Practice and Experience, 1985), on
 * how bitblt was made fast; Keith Packard, "A New Rendering Model for
 * X" (USENIX, 2000). *)

(* [draw dst r src mask p] draws src through mask into dst's rectangle
 * r; it is Plan 9's one operation. The point p of src (and of mask)
 * goes to r's corner. A colour as src fills r; a mask says where to
 * draw (with no mask, it is all of r). *)
val draw : Display.image -> Rectangle.t -> Display.image -> Display.image option -> Point.t -> unit
(* does the same, with the mask's point given separately (for a
 * character in a font's image) *)
val draw_mask : Display.image -> Rectangle.t -> Display.image -> Point.t -> Display.image -> Point.t -> unit

(* ix: [scale dst r src p k] draws src, from p, into dst's r, k times
 * larger: each pixel becomes k by k pixels, with no blending. This is
 * for a game's small picture on the whole screen, made larger by the
 * kernel's one loop (mini-9pi's 'z', not Plan 9's:
 * docs/plans/done/plan_playground_framebuffer.md, F5). dst and src must
 * have the same format. [can_scale dst src] says whether the device has
 * it (mini-9pi's C pixels, PIXEL=c, do not); it draws a pixel of dst to
 * find out. *)
val scale : Display.image -> Rectangle.t -> Display.image -> Point.t -> int -> unit
val can_scale : Display.image -> Display.image -> bool
(* ix: [shrink dst r src p k] draws src, from p, into dst's r, k times
 * smaller: a pixel of dst for each k by k pixels of src, taking the
 * nearest (mini-9pi's 'Z', for a window made a thumbnail by Expose).
 * [can_shrink dst src] says whether the device has it. *)
val shrink : Display.image -> Rectangle.t -> Display.image -> Point.t -> int -> unit
val can_shrink : Display.image -> Display.image -> bool

(* [fill] fills a rectangle; [border] draws its border, n pixels wide,
 * inside it *)
val fill : Display.image -> Rectangle.t -> Display.image -> unit
val border : Display.image -> Rectangle.t -> int -> Display.image -> unit

(* [line dst p0 p1 thick src] draws a line from p0 to p1, 1 + 2 * thick
 * pixels wide *)
val line : Display.image -> Point.t -> Point.t -> int -> Display.image -> unit

(* [poly dst points thick src] draws the lines from each point to the
 * next, 1 + 2 * thick pixels wide. [fillpoly] fills what they enclose,
 * with the last point joined to the first. A point is inside when the
 * edges around it do not cancel out, so a shape that crosses itself is
 * filled whole. *)
val poly : Display.image -> Point.t list -> int -> Display.image -> unit
val fillpoly : Display.image -> Point.t list -> Display.image -> unit

(* [ellipse dst c a b thick src] draws the ellipse of centre c and half
 * axes a (across) and b (down), with a line 1 + 2 * thick pixels wide;
 * [fillellipse] fills its inside *)
val ellipse : Display.image -> Point.t -> int -> int -> int -> Display.image -> unit
val fillellipse : Display.image -> Point.t -> int -> int -> Display.image -> unit
