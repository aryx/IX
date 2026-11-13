(* Tiny graphics is the essence of Plan 9's draw library (libdraw and
 * libmemdraw, whose twins in ix are lib_graphics/ and mini-9pi's
 * lib_memdraw), for tiny-machine's screen of 1024 by 768 pixels. A
 * pixel is one byte, an index in Plan 9's colour table. This is not a
 * program but the part of the kernel that draws (plan_tiny_windows.md).
 *
 * It needs a few functions on the machine's bytes, from KRaw: peekb
 * and pokeb, plus loops over a row (copy, fill, set a colour where a
 * mask is set, mix a colour by a mask's levels, draw a text's
 * characters). They are written in assembly on tiny-machine and work
 * on an array on the host.
 *
 * kept:
 * Of Plan 9's draw library, this module keeps:
 * - {b One operation}, [draw dst r src mask p]. The pixels of dst's
 *   rectangle r are copied from src, starting at point p, wherever
 *   the mask's pixels are set (everywhere when there is no mask).
 *   Filling a rectangle, copying a window to the screen, scrolling a
 *   text (an image drawn on itself), and drawing a character (the font
 *   is the mask, and the ink is the source) are all this one operation.
 * - {b A colour is an image} of one pixel that repeats. So draw needs
 *   no colour argument, and a pattern costs nothing more.
 * - {b The kernel has the pixels; a program says what to draw}. A
 *   program writes messages (a letter, then 16-bit numbers) that name
 *   images by numbers of its own choosing, and [messages] decodes them
 *   for the program's connection. So a program draws without reaching
 *   the screen's memory, which the kernel's partitions could not give
 *   it, and a window system can forward a program's messages after
 *   renumbering the images.
 *
 * Here is the one operation, drawn. The pixel of dst at (x, y), for each (x,
 * y) of r, becomes the pixel of src at (x, y) moved by p - r's corner,
 * if the mask's pixel at that same point is set:
 *
 *         src (and the mask)                  dst
 *     +--------------------+          +------------------+
 *     |    p               |          |                  |
 *     |     +-------+      |          |  r +-------+     |
 *     |     | these | -----|--------> |    | here  |     |
 *     |     +-------+      |          |    +-------+     |
 *     +--------------------+          +------------------+
 *
 * r is first clipped to dst, then to where src and the mask have
 * pixels, so nothing is ever read or written outside an image (an
 * image that repeats has a pixel everywhere). Here is what a program
 * does with it:
 *
 *     fill a rectangle       draw dst r colour, no mask, any p
 *                            (the colour is 1 by 1 and repeats)
 *     show a window          draw screen r window, no mask, p is r's
 *                            corner in the window's coordinates
 *     scroll a text up       draw w (all but the last line) w, no
 *                            mask, p 16 lower: w is drawn on itself
 *     draw a character       draw dst (its 8 by 16 cell) ink, with
 *                            the font as the mask, p = (8 * code, 0):
 *                            the font is one image, 1024 by 16
 *
 * Here are the 19 bytes that fill the rectangle from (10, 20) to
 * (30, 40) of image 0 with image 1 (TinyLibDraw's
 * d_fill 0 1 10 20 30 40):
 *
 *     d   00 00   01 00   ff ff   0a 00 14 00 1e 00 28 00   00 00 00 00
 *         dst 0   src 1   no mask the rectangle             p
 *
 * The messages are each a letter followed by signed 16-bit numbers,
 * low byte first. Image 0 is the connection's own image (its window,
 * or the screen):
 *
 *     a id x0 y0 x1 y1 repl colour    make an image of that rectangle and
 *                                     colour (freeing any image with that id)
 *     f id                            free an image
 *     d dst src mask x0 y0 x1 y1 px py      draw (mask -1 means none)
 *     l dst src x0 y0 x1 y1           a line, both ends included
 *     s dst src x y n, n bytes        a text, its top left corner at (x, y)
 *     t dst src x y n style, n bytes  a text in a style: bold 1, italic 2,
 *                                     underlined 4, large 8 (16 by 32);
 *                                     or 16 for fat pixels: each byte is a
 *                                     colour, drawn as a 4 by 4 square
 *     p dst x y n, n bytes            a row of pixels, its left end at (x, y)
 *
 * They are a few of Plan 9's own draw messages (principia's
 * kernel/devices/screen/drawmesg.c has 27); f, d and s keep their
 * letters. What we dropped is listed below.
 *
 * dropped:
 * - Pixels of other depths and channels. Here a pixel is always one
 *   byte, an index in the colour table.
 * - Alpha and Porter and Duff's operators. A mask is either set or
 *   not, except for a colour drawn through a font with grey levels
 *   (grey.font), which is mixed by a table made for that colour.
 * - A clipping rectangle other than the image's own, and a separate
 *   point for the mask (the mask uses the source's, as in libdraw's
 *   draw).
 * - Ellipses, arcs, polygons and thick lines.
 * - Fonts and their cache. There is one font, the machine's 8 by 16
 *   font, with its bold face and its large 16 by 32 face; italic is
 *   made by slanting them. Or the font is font1.bin alone, and bold and
 *   large are made from it too.
 * - Layers and windows (TinyWindows.ml composes whole images), and
 *   the screen's refresh.
 *
 * twist:
 * {b A text has a style, and the kernel makes its faces.} Plan 9's
 * string message names a font that the program loaded, and gives the
 * characters by their places in that font's cache (principia's
 * drawmesg.c), so a bold or a large text is another font to load. Here
 * t carries the characters themselves and a few bits of style. Bold and
 * large are the font's own faces when it has them. Otherwise they are
 * made from its one face the first time a text asks for them: for
 * large, each pixel is doubled, and for bold, each character is drawn
 * twice, a pixel apart. Italic is made by slanting. A word
 * processor's styles then cost a program only a number.
 *
 * context:
 * Below this module is KRaw (bytes, and three loops over a row).
 * Around it is TinyKernel, which gives each program a connection and
 * calls [messages] with what the program writes on its descriptor 3.
 * On the other side of those bytes are TinyLibDraw, which makes them,
 * and TinyWindows, which renumbers them. In m-ix the same three parts
 * are lib_graphics's Draw (the program's side), the kernel's draw
 * device, and lib_memdraw (the pixels), with channels, depths and
 * alpha.
 *
 * exercises:
 * - copy a row a word at a time where possible (kdraw.s's row_copy);
 * - ellipses and filled polygons, for the playground's shapes;
 * - masks with any level from 0 to 255, and sources other than a
 *   single colour mixed through them (here there are four levels, and
 *   only for a colour through the font);
 * - a clipping rectangle per image, set by a message (the visible part
 *   of a window).
 *
 * cs-history:
 * One operation that copies a rectangle of bits, combined with what
 * is there, is BitBlt (Dan Ingalls, Xerox PARC, mid-1970s, for the
 * Alto and Smalltalk). With it, windows, text, scrolling and pop-up
 * menus all depended on one loop to make fast, and the bitmap display
 * became usable. It had sixteen ways to combine source and
 * destination, and a fill pattern beside the source. Rob Pike's
 * Blit (1982) carried it to Unix; Plan 9's draw (its third edition,
 * 2000) replaced the sixteen ways and the pattern by
 * two ideas kept here: a mask, and a source that repeats.
 *
 * others:
 * The mask of levels left as an exercise is Porter and Duff's
 * compositing, which is what every system now draws with: PDF,
 * Quartz, Cairo, the HTML canvas, and ix's own lib_graphics software
 * renderer and mini-netscape's painting. They add paths filled
 * with antialiasing and a matrix on the coordinates; the rectangle
 * copied through a mask is still the operation at the bottom.
 *
 * plan9-is-cleaner:
 * In X11 a program sets up a graphics context (a function, a
 * foreground, a fill style, a tile, a stipple, a clip mask...) and
 * then calls one of many requests: fill a rectangle, copy an area,
 * draw a string. In Plan 9 a colour, a pattern, a picture and a
 * font's character are all the same thing, an image, and one call
 * with three images does what those requests do; the library is
 * small because there is one inner loop to get right.
 *
 * references:
 *  - R. Pike, "Graphics in Overlapping Bitmap Layers" (ACM TOG 1983):
 *    the Blit's bitblt
 *  - R. Pike et al., "Plan 9 from Bell Labs" (1995) and draw(2),
 *    draw(3): the one operation, and images named by numbers
 *  - T. Porter and T. Duff, "Compositing Digital Images" (SIGGRAPH
 *    1984): what a mask of levels would bring
 *  - J. Bresenham, "Algorithm for computer control of a digital
 *    plotter" (IBM Systems Journal 1965): the line
 *)

(* Raised for a bad message or a drawing that cannot be done. *)
exception Graphics of string

(* A rectangle's second corner (x1, y1) is just outside it. An image's
 * [at] is the address of its bytes in memory. *)
type rect = { x0 : int; y0 : int; x1 : int; y1 : int }
type image = { r : rect; at : int; repl : bool }
val rect : int -> int -> int -> int -> rect

(* [draw dst r src mask px py] is the one operation. The rectangle r of
 * dst takes the pixels of src from point (px, py), wherever the mask is
 * set (or everywhere when there is no mask). *)
val draw : image -> rect -> image -> image option -> int -> int -> unit

(* This is the memory for the images that programs make, outside the
 * collected heap. [arena at size] sets the whole area; [blocks] is the
 * free list. *)
val arena : int -> int -> unit
val free : int -> int -> unit
val alloc : int -> int
val blocks : (int * int) list ref

(* [font_mask bits size at] makes a font's first face into a 16 KB mask
 * at address at; its other faces stay for styled texts. The font is
 * font1.bin, tiny.font or grey.font (with grey levels; see
 * fonts/README.md). *)
val font_mask : int -> int -> int -> image

(* A conn holds a program's images, by its own numbers; 0 is the one it
 * draws on.
 * [messages c s] skips a bad message and raises Graphics after the
 * rest; a message cut short or unknown raises it at once. *)
type conn
val connect : image -> image -> conn
val disconnect : conn -> unit
val messages : conn -> string -> unit
(* This hook runs for the 'c' message, which sets the cursor's look.
 * The kernel sets it to write the machine's mouse word; on the host it
 * does nothing. *)
val cursor_hook : (int -> unit) ref
