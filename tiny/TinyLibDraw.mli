(* The program side of KGraphics.ml. This file builds the
 * drawing messages (each one a string, to be concatenated and written
 * to the file descriptor the program draws on), and it also parses
 * them (a window system reads the messages of another program,
 * renumbers their images, and passes them on: see TinyWindows.ml).
 * The Plan 9 equivalent is libdraw, the library used by programs,
 * while KGraphics.ml plays the role of the kernel's draw
 * device and of libmemdraw. For C programs, the equivalent is
 * runtime/c/draw.h.
 *
 * The messages are described in the header of KGraphics.mli:
 * a letter, followed by signed 16-bit numbers, low byte first.
 *
 * Here is the path of a rectangle from a program to the screen, on the
 * two machines where the same ML files run:
 *
 *     a program            TinyAppTetris on TinyLibPlayground, TinyWindows
 *        | d_fill ...      this file: makes a string of 19 bytes
 *        | written on 3    TinyLibSystem.write fd_draw: on tiny-machine a
 *        |                 system call; on the host the tests' stub,
 *        |                 which keeps it for the test to check
 *        | (through a pipe, renumbered by TinyWindows, when in a window)
 *        | [messages]      KGraphics: inside TinyKernel; on the
 *        |                 host, called directly by the test
 *        | pokeb, rows     on tiny-machine: C and assembly (TinyKernel's
 *        |                 KRaw.ml); on the host: KRaw, an array
 *     the screen's bytes   at 0xf00000 on both
 *
 * So the three files between a program and its machine (this one,
 * TinyLibSystem and KRaw) are where the host takes the machine's
 * place, and everything above them is tested by dune before
 * tiny-machine ever runs it.
 *
 * twin:
 * m-ix's lib_graphics has Draw and Display (libdraw's, by way of xix):
 * a Display that keeps the messages until [flush], images as records,
 * numbers of four bytes.
 *
 * kept:
 * - {b A message is a string returned}: no Display, no Image record,
 *   no buffer of the library's; the program concatenates them and
 *   writes them when it wants them shown.
 * - {b Numbers of two bytes}, where libdraw's are four: a screen of
 *   1024 by 768 needs no more.
 * - {b Eight letters} (a f d l s t p c), the operations
 *   KGraphics keeps.
 * - {b The messages are parsed too} ([d_shape]), which libdraw has no
 *   need of: on Plan 9 a window's program writes to the kernel's draw
 *   device itself, finding its window's image by the name in
 *   /dev/winname, and rio never reads its messages. Here TinyWindows
 *   forwards them, renumbered.
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

(* What the messages are about, each an int or ints still: an image's
 * number (a colour is an image too, one pixel that repeats); a colour's
 * value, a pixel's byte; a rectangle by its corners, x0 y0 in it, x1
 * y1 out; a point; a text's style, bits (below); the mouse's look
 * (old: ints in a row, up to nine) *)
type image = int
type pixel = int
type rect = int * int * int * int
type point = int * int
type style = int
type cursor = Cursor_arrow | Cursor_hand

(* tiny-machine's screen, 1024 by 768 pixels *)
val screen_w : int
val screen_h : int

(* [d_image id r colour]: an image of the rectangle r, filled with a
 * colour; [d_colour id colour]: a colour; [d_free id]: an image freed *)
val d_image : image -> rect -> pixel -> string
val d_colour : image -> pixel -> string
val d_free : image -> string

(* [d_draw dst src mask r p], KGraphics's draw (-1: no mask),
 * src's pixels from p on; a rectangle of a colour; a line between two
 * points; a text at a corner *)
val d_draw : image -> image -> image -> rect -> point -> string
val d_fill : image -> image -> rect -> string
val d_line : image -> image -> point -> point -> string
val d_text : image -> image -> point -> string -> string

(* [d_styled dst src p style s]: a text in a style, bold 1, italic 2,
 * underlined 4, large 8 (16 by 32 a character); or 16, fat pixels, each
 * byte a colour, a square of 4 by 4 (src unused) *)
val d_styled : image -> image -> point -> style -> string -> string

(* [d_pixels dst p bytes]: a row of pixels, its left end at p *)
val d_pixels : image -> point -> string -> string

(* [d_cursor c]: the mouse's look, the arrow or a hand (a browser's over
 * a link). The kernel sets the machine's (by writing the mouse's
 * word), which the host shows; tiny-windows keeps each window's, and
 * shows the front window's while the mouse is in it. *)
val d_cursor : cursor -> string

(* [d_shape s i]: the message at i of s, its length (beyond the
 * string's end when it is not all there, -1 when it is no message) and
 * how many of its first numbers are images: what a window system
 * renumbers *)
type message_shape = { ds_length : int; ds_images : int }
val d_shape : string -> int -> message_shape

(* The mouse as the kernel's descriptor 4 says it, a message of 12
 * bytes: where it is, and its buttons (1 left, 2 middle, 4 right; -1:
 * tiny-windows' answer to an ENQ, the window's size in mo_x and mo_y);
 * None when the 12 bytes are not all there *)
type mouse_event = { mo_x : int; mo_y : int; mo_buttons : int }
val mouse_event : string -> mouse_event option

(* The bytes: a number's two bytes, the low one first; the number at i
 * of a string; a message, its letter then its numbers *)
val i16 : int -> string
val int16 : string -> int -> int
val msg : char -> int list -> string
