(* '#i', the draw device (principia's devdraw.c, drawmesg.c and their
 * drawalloc.c, drawname.c, drawwindow.c, drawmisc.c): the screen shared
 * by its clients, each a directory of /dev/draw (new: a new client's
 * ctl), its images by number. A client writes messages to its data
 * file (drawmesg: 'b' an image, 'd' a drawing, 's' a string, 'y' pixels
 * loaded, 'A' a screen, 'b' on it a window, 't' windows to the front,
 * ...: draw.h's protocol), reads its ctl (an image's size and chan: the
 * screen's first), and names images for others to use ('N', 'n': the
 * screen is "noborder.screen.1"). The pixels are principia's libraries'
 * (Draw's primitives); the numbers, names, fonts' characters, screens
 * and refreshes are here.
 *
 * Not as 9pi: no flushes (9pi's are nothing on the Pi: its screen is
 * not a soft one), no blanking after 30 minutes (its colour map is
 * nothing on an RGB16 screen, 9pi skips it under emulation), and the
 * colormap file's 256 colours are 0 (9pi's arch_getcolor leaves them
 * unset).
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
 * Images live in the kernel and are named by small numbers the
 * client chooses, as 9P's fids are; a picture is loaded once (y) and
 * drawn many times by a message of 45 bytes, a string (s) is a font's
 * image and a list of indices. That is what makes the protocol fit
 * for a slow line. Under this file the pixels are Kdraw's (the
 * composition: lib_memdraw's Memdraw), and a window is
 * lib_memlayer's.
 *
 * reframe:
 * The screen is a file server too. X11 puts a server process
 * between programs and the display, with its own protocol on its
 * own socket, its own naming of displays, its own authorization.
 * Here the protocol is writes to a file, so everything files have
 * comes free: the name space decides which screen a program draws
 * on, a window system is a program that serves another /dev/draw
 * (or, as rio, hands out windows of this one by name), and a
 * program on a remote machine draws here because its /dev is this
 * machine's, with no forwarding to set up.
 *
 * cs-history:
 * The line runs from the Blit (Rob Pike and Bart Locanthi, Bell
 * Labs, 1982), a terminal with a processor that drew its own
 * windows, through 8 1/2, Plan 9's first window system (1991),
 * whose kernel device spoke bitblt: sixteen ways to combine two
 * bits. The draw device replaced it with the third edition (2000,
 * from memory): one operator, the composition of a source through a
 * mask onto a destination with alpha (Memdraw), and with it rio.
 *
 * References: draw(3) in the Plan 9 manual: every message, a line
 * each. Rob Pike, "8 1/2, the Plan 9 Window System" (USENIX Summer
 * 1991) and "rio: Design of a Concurrent Window System" (a talk,
 * 2000). principia's Kernel.nw, Graphics.nw and Windows.nw. *)

(* the device registered *)
val init : unit -> unit
