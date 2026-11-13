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
 * m-ix's lib_graphics has Draw and Display, which come from libdraw by
 * way of xix. There, a Display buffers the messages until [flush], an
 * image is a record, and numbers take four bytes.
 *
 * kept:
 * - {b Each function returns a message as a string}. There is no
 *   Display, no Image record and no buffer in the library: the program
 *   concatenates the messages and writes them when it wants them shown.
 * - {b Numbers take two bytes}, where libdraw's take four: a screen of
 *   1024 by 768 needs no more.
 * - {b There are eight letters} (a f d l s t p c), one for each
 *   operation that KGraphics keeps.
 * - {b The messages can be parsed too} ([d_shape]), which libdraw has
 *   no need for: on Plan 9 a window's program writes to the kernel's draw
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

(* A colour is an image too: one pixel that repeats. A pixel is one
 * byte. A rect has x0 y0 inside it and x1 y1 just outside. *)
type image = int
type pixel = int
type rect = int * int * int * int
type point = int * int
type style = int (* bits, see [d_styled] *)
type cursor = Cursor_arrow | Cursor_hand

(* tiny-machine's screen, 1024 by 768 pixels *)
val screen_w : int
val screen_h : int

(* [d_image id r colour] makes an image of the rectangle r. *)
val d_image : image -> rect -> pixel -> string
val d_colour : image -> pixel -> string
val d_free : image -> string

(* [d_draw dst src mask r p] is KGraphics's draw: it copies the pixels
 * of src from p on into r; a mask of -1 means no mask. *)
val d_draw : image -> image -> image -> rect -> point -> string
val d_fill : image -> image -> rect -> string
val d_line : image -> image -> point -> point -> string
val d_text : image -> image -> point -> string -> string

(* [d_styled dst src p style s] draws s in a style whose bits are bold
 * 1, italic 2, underlined 4 and large 8 (16x32 characters). Style 16,
 * fat pixels, draws each byte of s as a 4x4 square of that colour, and
 * src is unused. *)
val d_styled : image -> image -> point -> style -> string -> string

(* [d_pixels dst p bytes] draws a row of pixels, with its left end at p *)
val d_pixels : image -> point -> string -> string

(* tiny-windows keeps a cursor per window, shown while the mouse is in
 * the front window. *)
val d_cursor : cursor -> string

(* [d_shape s i] describes the message at i in s. [ds_length] goes past
 * the end of s when the message is not all there, and is -1 when the
 * bytes are not a message. [ds_images] counts the leading numbers that
 * are images, which a window system must renumber. *)
type message_shape = { ds_length : int; ds_images : int }
val d_shape : string -> int -> message_shape

(* The 12-byte message read from the kernel's descriptor 4; it is None
 * when the message is not all there. The buttons are 1 for left, 2 for
 * middle and 4 for right. -1 marks the answer of tiny-windows to an
 * ENQ, with the window's size in x and y. *)
type mouse_event = { mo_x : int; mo_y : int; mo_buttons : int }
val mouse_event : string -> mouse_event option

(* Numbers are two bytes, the low one first. [msg c ns] is the letter c
 * followed by the numbers. *)
val i16 : int -> string
val int16 : string -> int -> int
val msg : char -> int list -> string
