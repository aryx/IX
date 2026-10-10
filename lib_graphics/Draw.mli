(* Drawing (Plan 9's libdraw; xix's lib_graphics/draw): each function a
 * message of the draw device's, on a Display's images.
 *
 * One operation does nearly all of it, [draw]: three images, laid on
 * one another at a rectangle of the first,
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
 * the mask's value from 0 (dst is left) to 1 (src replaces it), a
 * bit or a byte a pixel, or the alpha of an image that has one. What
 * the three are says what the operation is:
 *
 *     src            mask                 it is
 *     a colour       none                 a rectangle filled ([fill])
 *     an image       none                 a copy: a picture shown, what
 *                                         a menu covered put back (Menu)
 *     a colour       a font's image       a character in that colour
 *                                         (Font.string)
 *     a colour       a grey image         a shape with smooth edges; a
 *                                         shadow
 *     an image       a colour, half       the image seen through
 *
 * A colour is an image like the others: one pixel that repeats over
 * the plane (Display.color), so no function takes a colour and an
 * image apart. And no mask is the white one (Display.opaque).
 *
 * The shapes ([line], [poly], [ellipse]) are messages too: the kernel
 * finds their pixels (mini-9pi's Memshape) and paints src there, the
 * shape in the place of the mask. A program that would rather find
 * the pixels itself, with smooth edges, draws in its own memory
 * (Framebuffer, with Line, Fill, Circle and Stroke) and gives the
 * rows to an image (Display.load): what lib_playground's games do.
 *
 * A polygon's points are sent short, a coordinate as its difference
 * from the one before: a byte when it is from -64 to 63, else three
 * with the whole coordinate (the first byte's high bit says which).
 * A curve made of many small steps is two bytes a point.
 *
 * cs-history:
 * Bitblt before it. Dan Ingalls's BitBlt (Xerox PARC, 1975, for
 * Smalltalk on the Alto) copied a rectangle of bits onto another
 * through a boolean function of the two, one of sixteen: replace,
 * or, and, and the exclusive or that draws a cursor or a rubber band
 * and takes it away by being done twice. Pike's bitblt on the Blit
 * and in Plan 9's first editions was that operation. It has no
 * meaning on pixels that are colours: the exclusive or of two reds
 * is no colour one chose. Thomas Porter and Tom Duff (Lucasfilm,
 * 1984) had given a pixel a fourth number, alpha, how much of the
 * pixel the colour covers, and twelve ways to combine two such
 * pictures, of which "over" is paint and "in" a stencil. Plan 9's
 * draw (2000) is those two as the one operation, dst = (src in mask)
 * over dst, in the place of the sixteen functions; the other
 * operators came later, as a number in a message of its own (the
 * kernel's Memdraw has them).
 *
 * others:
 * X11's first protocol (1987) has the sixteen functions, in a
 * graphics context kept by the server, and separate requests for a
 * copy, a filled rectangle and a string of characters. Its Render
 * extension (Keith Packard, 2000) added compositing as one
 * request, Composite, of an operator and three pictures: a source, a
 * mask and a destination, as here, and said from where it took them.
 * The canvas of a web page, PDF's transparency (Pdf_canvas) and a
 * graphics card's blending are the same "over".
 *
 * design:
 * One general operation where there were several. The cases that
 * must be fast (a colour with no mask, a copy between images of the
 * same format) are found by the one who implements it, by looking at
 * the arguments, not chosen by the caller among functions: the
 * interface stays one line, and a combination nobody thought of (a
 * picture through another picture's alpha) works the first time.
 *
 * References: draw(2) of Plan 9's manual; Thomas Porter and Tom Duff,
 * "Compositing Digital Images" (SIGGRAPH 1984), the operators and
 * why colours are kept multiplied by their alpha; Rob Pike, Bart
 * Locanthi and John Reiser, "Hardware/Software Trade-offs for Bitmap
 * Graphics on the Blit" (Software: Practice and Experience, 1985),
 * bitblt made fast; Keith Packard, "A New Rendering Model for X"
 * (USENIX, 2000; from memory). *)

(* [draw dst r src mask p]: src through mask into dst's rectangle r,
 * Plan 9's one operation: src's point p (and mask's) goes to r's
 * corner. A colour as src fills r; a mask says where (none: all of r). *)
val draw : Display.image -> Rectangle.t -> Display.image -> Display.image option -> Point.t -> unit
(* the same, the mask's point said apart (a character in a font's image) *)
val draw_mask : Display.image -> Rectangle.t -> Display.image -> Point.t -> Display.image -> Point.t -> unit

(* a rectangle filled; its border, n pixels wide, inside it *)
val fill : Display.image -> Rectangle.t -> Display.image -> unit
val border : Display.image -> Rectangle.t -> int -> Display.image -> unit

(* [line dst p0 p1 thick src]: a line from p0 to p1, 1 + 2 * thick pixels wide *)
val line : Display.image -> Point.t -> Point.t -> int -> Display.image -> unit

(* [poly dst points thick src]: the lines from each point to the next,
 * 1 + 2 * thick pixels wide; [fillpoly]: what they enclose, the last
 * point joined to the first (a point is inside when the edges round it
 * do not cancel out: a shape that crosses itself is filled whole) *)
val poly : Display.image -> Point.t list -> int -> Display.image -> unit
val fillpoly : Display.image -> Point.t list -> Display.image -> unit

(* [ellipse dst c a b thick src]: the ellipse of centre c and half axes
 * a (across) and b (down), its line 1 + 2 * thick pixels wide;
 * [fillellipse]: its inside *)
val ellipse : Display.image -> Point.t -> int -> int -> int -> Display.image -> unit
val fillellipse : Display.image -> Point.t -> int -> int -> Display.image -> unit

