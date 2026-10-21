(* The program side of TinyKernelGraphics.ml. This file builds the
 * drawing messages (each one a string, to be concatenated and written
 * to the file descriptor the program draws on), and it also parses
 * them (a window system reads the messages of another program,
 * renumbers their images, and passes them on: see TinyWindows.ml).
 * The Plan 9 equivalent is libdraw, the library used by programs,
 * while TinyKernelGraphics.ml plays the role of the kernel's draw
 * device and of libmemdraw. For C programs, the equivalent is
 * TinyKernel/libc/draw.h.
 *
 * The messages are described in the header of TinyKernelGraphics.mli:
 * a letter, followed by signed 16-bit numbers, low byte first.
 *
 * Here is the path of a rectangle from a program to the screen, on the
 * two machines where the same ML files run:
 *
 *     a program            TinyAppTetris on TinyLibPlayground, TinyWindows
 *        | d_fill ...      this file: makes a string of 19 bytes
 *        | written on 3    on tiny-machine: a system call (TinyKernel/
 *        |                 libml's TinyCalls.ml); on the host: TinyCalls,
 *        |                 which keeps it for the test to check
 *        | (through a pipe, renumbered by TinyWindows, when in a window)
 *        | [messages]      TinyKernelGraphics: inside TinyKernel; on the
 *        |                 host, called directly by the test
 *        | pokeb, rows     on tiny-machine: C and assembly (TinyKernel's
 *        |                 TinyMemory.ml); on the host: TinyMemory, an array
 *     the screen's bytes   at 0xf00000 on both
 *
 * So the three files between a program and its machine (this one,
 * TinyCalls and TinyMemory) are where the host takes the machine's
 * place, and everything above them is tested by dune before
 * tiny-machine ever runs it.
 *
 * plan9-is-cleaner:
 * Drawing by writing bytes to a file comes from Plan 9: its draw
 * device is a directory in /dev, and libdraw turns each call into a
 * message, a letter followed by numbers, written to one of the files
 * in that directory (there d draws, f frees an image, s draws a
 * string). Because it is a file, it can go through a pipe or over the
 * network like any other file, and a window system or a remote
 * terminal needs no protocol of its own.
 *)

(* a number's two bytes, the low one first, and the number at i of a
 * string; a message, its letter then its numbers *)
val i16 : int -> string
val int16 : string -> int -> int
val msg : char -> int list -> string

(* an image [d_image id x0 y0 x1 y1 colour], a colour (one pixel that
 * repeats), an image freed *)
val d_image : int -> int -> int -> int -> int -> int -> string
val d_colour : int -> int -> string
val d_free : int -> string

(* [d_draw dst src mask x0 y0 x1 y1 px py], TinyKernelGraphics's draw (-1: no
 * mask); a rectangle of a colour; a line; a text at a corner *)
val d_draw : int -> int -> int -> int -> int -> int -> int -> int -> int -> string
val d_fill : int -> int -> int -> int -> int -> int -> string
val d_line : int -> int -> int -> int -> int -> int -> string
val d_text : int -> int -> int -> int -> string -> string

(* [d_styled dst src x y style s]: a text in a style, bold 1, italic 2,
 * underlined 4, large 8 (16 by 32 a character); or 16, fat pixels, each
 * byte a colour, a square of 4 by 4 (src unused) *)
val d_styled : int -> int -> int -> int -> int -> string -> string

(* [d_pixels dst x y bytes]: a row of pixels, its left end at (x, y) *)
val d_pixels : int -> int -> int -> string -> string

(* [d_cursor kind]: the mouse's look, 0 the arrow, 1 a hand (a browser's
 * over a link). The kernel sets the machine's (by writing the mouse's
 * word), which the host shows; tiny-windows keeps each window's, and
 * shows the front window's while the mouse is in it. *)
val d_cursor : int -> string

(* the message at i of a string: its length (beyond the string's end
 * when it is not all there, -1 when it is no message) and how many of
 * its first numbers are images: what a window system renumbers *)
val d_shape : string -> int -> int * int
