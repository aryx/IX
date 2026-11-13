(* '#i' is the draw device (principia's devdraw.c and drawmesg.c, with
 * their drawalloc.c, drawname.c, drawwindow.c and drawmisc.c). It is the
 * screen, shared by its clients. Each client is a directory of /dev/draw
 * (opening new gives a new client's ctl), and holds its images by
 * number. A client:
 * - writes messages to its data file (drawmesg, which follows draw.h's
 *   protocol): 'b' allocates an image, 'd' draws, 's' draws a string,
 *   'y' loads pixels, 'A' allocates a screen, 'b' on a screen allocates
 *   a window, 't' brings windows to the front, and so on;
 * - reads its ctl, which gives an image's size and chan, the screen's
 *   first;
 * - names images for others to use ('N', 'n'; the screen is
 *   "noborder.screen.1").
 * The pixels are drawn by principia's libraries (Draw's primitives); the
 * numbers, names, fonts' characters, screens and refreshes are handled
 * here.
 *
 * Where this differs from 9pi:
 * - there are no flushes (9pi's do nothing on the Pi, whose screen is
 *   not a soft one);
 * - there is no blanking after 30 minutes (it goes through the colour
 *   map, which does nothing on an RGB16 screen, and 9pi skips it under
 *   emulation);
 * - the 256 colours of the colormap file are 0 (9pi's arch_getcolor
 *   leaves them unset).
 *
 * A program that paints a red rectangle on the screen:
 *
 *     open /dev/draw/new      a client is made, say number 3; a read
 *                             says so, and describes image 0, the
 *                             screen: its chan, its rectangle
 *     write /dev/draw/3/data  messages, end to end, a letter each:
 *       b  id 1, chan, repl 1, r (0,0)-(1,1), colour red
 *                             a new image: one pixel, tiled for ever
 *       d  dst 0, src 1, mask 2, r (10,10)-(110,60), two points
 *                             draw: the screen's rectangle from the
 *                             red image, through image 2, a mask (a
 *                             white pixel, made the same way: opaque)
 *
 *     the d message: 45 bytes, numbers the low byte first
 *     d  dstid[4] srcid[4] maskid[4]  r[4*4]  srcpoint[2*4]  maskpoint[2*4]
 *
 * Images live in the kernel and are named by small numbers that the
 * client chooses, as 9P's fids are. A picture is loaded once (y) and
 * drawn many times by a message of 45 bytes, and a string (s) is a
 * font's image and a list of indices. That is what makes the protocol
 * fit for a slow line. Under this file, the pixels are drawn by Kdraw
 * (the composition is lib_memdraw's Memdraw), and a window is
 * lib_memlayer's.
 *
 * reframe:
 * The screen is a file server too. X11 puts a server process between
 * programs and the display, with its own protocol on its own socket,
 * its own naming of displays, and its own authorization. Here the
 * protocol is writes to a file, so everything that files have comes for
 * free. The name space decides which screen a program draws on. A
 * window system is a program that serves another /dev/draw (or, as rio
 * does, hands out windows of this one by name). And a program on a
 * remote machine draws here because its /dev is this machine's, with no
 * forwarding to set up.
 *
 * cs-history:
 * The line runs from the Blit (Rob Pike and Bart Locanthi, Bell Labs,
 * 1982), a terminal with a processor that drew its own windows, to 8
 * 1/2, Plan 9's first window system (1991), whose kernel device spoke
 * bitblt: sixteen ways to combine two bits. The draw device replaced it
 * with the third edition (2000). It has one operator, the composition of
 * a source through a mask onto a destination with alpha (Memdraw), and
 * rio came with it.
 *
 * References: draw(3) in the Plan 9 manual, which gives every message
 * a line. Rob Pike, "8 1/2, the Plan 9 Window System" (USENIX Summer
 * 1991) and "rio: Design of a Concurrent Window System" (a talk,
 * 2000). principia's Kernel.nw, Graphics.nw and Windows.nw. *)

(* registers the device *)
val init : unit -> unit
