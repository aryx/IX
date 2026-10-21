(* Tiny graphics: the essential of Plan 9's draw library (libdraw and
 * libmemdraw; ix's twins are lib_graphics/ and mini-9pi's
 * lib_memdraw), for tiny-machine's screen: 640 by 480 pixels, a byte
 * each, a colour of Plan 9's table. Not a program: TinyKernel.ml's part
 * that draws (plan_tiny_windows.md).
 *
 * It asks five functions of bytes of its machine, TinyMemory's: peekb
 * and pokeb, and a row's three loops (copied, filled, a colour where a
 * mask is set), which are assembly on tiny-machine and an array's on
 * the host.
 *
 * What is kept of Plan 9's:
 *
 * - {b One operation}, [draw dst r src mask p]: the pixels of dst's
 *   rectangle r are src's from the point p on, where mask's are set
 *   (everywhere without one). A rectangle filled, a window copied to
 *   the screen, a text scrolled (an image drawn on itself), a
 *   character (the font is a mask, the ink the source) are all it.
 * - {b A colour is an image}, of one pixel, that repeats: so draw needs
 *   no colour argument, and a pattern costs nothing more.
 * - {b The kernel has the pixels, a program says what}: a program
 *   writes messages (a letter, then numbers of 16 bits) naming images
 *   by numbers of its own; [messages] decodes them for a connection.
 *   So a program draws without reaching the screen's memory, which
 *   TinyKernel.ml's partitions could not give it, and a window system
 *   forwards a program's messages after changing the numbers.
 *
 * The one operation, drawn. The pixel of dst at (x, y), for each (x,
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
 * r is first cut to what dst has, then to what src and the mask have
 * pixels for, so nothing is ever read or written outside an image;
 * an image that repeats has a pixel everywhere. What a program does
 * with it:
 *
 *     a rectangle filled     draw dst r colour, no mask, any p
 *                            (the colour: 1 by 1, repeating)
 *     a window shown         draw screen r window, no mask, p r's
 *                            corner in the window's coordinates
 *     a text scrolled up     draw w (all but the last line) w, no
 *                            mask, p 16 lower: drawn on itself
 *     a character            draw dst (its cell, 8 by 16) ink, the
 *                            font as the mask, p (8 * its code, 0):
 *                            the font is one image, 1024 by 16
 *
 * and as bytes, a rectangle from (10, 20) to (30, 40) of image 0
 * filled with image 1 (TinyLibDraw's d_fill 0 1 10 20 30 40), 19 bytes:
 *
 *     d   00 00   01 00   ff ff   0a 00 14 00 1e 00 28 00   00 00 00 00
 *         dst 0   src 1   no mask the rectangle             p
 *
 * Dropped: pixels of other depths and channels (one byte, the table's
 * index), alpha and Porter and Duff's operators (a mask is set or not),
 * a clipping rectangle apart from an image's own, a mask's own point
 * (it is the source's, as libdraw's draw), ellipses, arcs, polygons and
 * thick lines, fonts (one, the machine's 8 by 16, and what is made of
 * it: italic, slanted, and large, its pixels doubled) and their cache,
 * layers and windows (TinyWindows.ml composes whole images), the
 * screen's refresh.
 *
 * The messages, each a letter then 16-bit numbers, the low byte first,
 * signed; an image 0 is the connection's own (its window, or the
 * screen):
 *
 *     a id x0 y0 x1 y1 repl colour    an image made, of that rectangle and colour
 *                                     (the one that had this number freed)
 *     f id                            freed
 *     d dst src mask x0 y0 x1 y1 px py      draw (mask -1: none)
 *     l dst src x0 y0 x1 y1           a line, both ends drawn
 *     s dst src x y n, n bytes        a text, its top left corner at (x, y)
 *     t dst src x y n style, n bytes  a text in a style: bold 1, italic 2,
 *                                     underlined 4, large 8 (16 by 32);
 *                                     or 16, fat pixels: a byte a colour,
 *                                     a square of 4 by 4
 *     p dst x y n, n bytes            a row of pixels, its left end at (x, y)
 *
 * Exercises:
 * - a row copied a word at a time where it can (draw.tm's row_copy);
 * - ellipses and filled polygons, for the playground's shapes;
 * - a mask of levels, 0 to 255: a pixel mixed, and a font with grey
 *   edges;
 * - a clipping rectangle per image, set by a message (a window's part
 *   that shows).
 *
 * Where it stands: under it TinyMemory (bytes, and three loops over a
 * row); around it TinyKernel, which gives each program a connection
 * and calls [messages] with what the program writes on its
 * descriptor 3; on the other side of those bytes TinyLibDraw, which
 * makes them, and TinyWindows, which renumbers them. In m-ix the
 * same three are lib_graphics's Draw (the program's side), the
 * kernel's draw device, and lib_memdraw (the pixels), with channels,
 * depths and alpha.
 *
 * cs-history:
 * One operation that copies a rectangle of bits, combined with what
 * is there, is BitBlt (Dan Ingalls, Xerox PARC, mid-1970s, for the
 * Alto and Smalltalk): with it windows, text, scrolling and menus
 * that pop up were one loop to make fast, and the bitmap display
 * became usable. It had sixteen ways to combine source and
 * destination, and a fill pattern beside the source. Rob Pike's
 * Blit (1982) carried it to Unix; Plan 9's draw (its third edition,
 * 2000) replaced the sixteen ways and the pattern by
 * two ideas kept here: a mask, and a source that repeats.
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
 * others:
 * The mask of levels left as an exercise is Porter and Duff's
 * compositing, which is what every system now draws with: PDF,
 * Quartz, Cairo, the HTML canvas (ix's own: lib_graphics's software
 * renderer, and mini-netscape's painting). They add paths filled
 * with antialiasing and a matrix on the coordinates; the rectangle
 * copied through a mask is still the operation at the bottom.
 *
 * References: R. Pike, "Graphics in Overlapping Bitmap
 * Layers" (ACM TOG 1983), the Blit's bitblt; R. Pike et al., "Plan 9
 * from Bell Labs" (1995) and draw(2), draw(3): the one operation, an
 * image a file's number; T. Porter and T. Duff, "Compositing Digital
 * Images" (SIGGRAPH 1984), what a mask of levels would bring; J.
 * Bresenham, "Algorithm for computer control of a digital plotter"
 * (IBM Systems Journal 1965), the line. *)

(* what a bad message or a drawing that cannot be is answered with *)
exception Graphics of string

(* a rectangle, its second corner outside it; an image: its rectangle,
 * where its bytes are in memory, whether it repeats *)
type rect = { x0 : int; y0 : int; x1 : int; y1 : int }
type image = { r : rect; at : int; repl : bool }
val rect : int -> int -> int -> int -> rect

(* The one operation, [draw dst r src mask px py]: dst's rectangle r
 * takes src's pixels from the point (px, py) on, where the mask's are
 * set (everywhere without one) *)
val draw : image -> rect -> image -> image option -> int -> int -> unit

(* the memory the images a program makes are in, outside the collected
 * heap: [arena at size] is all of it, [free at size] a block more,
 * [alloc size] a block taken, its address; [blocks] what is free (a
 * test's) *)
val arena : int -> int -> unit
val free : int -> int -> unit
val alloc : int -> int
val blocks : (int * int) list ref

(* the font as a mask: its bits, at an address, made bytes at another *)
val font_mask : int -> int -> image

(* a program's connection: its images by its own numbers, 0 the one it
 * was given to draw on; [connect screen font]. [messages] does a
 * string of them (Graphics when one is bad); [disconnect] frees what
 * the program left *)
type conn
val connect : image -> image -> conn
val disconnect : conn -> unit
val messages : conn -> string -> unit
(* what the 'c' message (the mouse's look) does: set by the kernel,
 * which writes it to the machine's mouse word; nothing on the host *)
val cursor_hook : (int -> unit) ref
