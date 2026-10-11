(* A program's side of TinyGraphics.ml: its messages, made (a string
 * each, to join and write to the descriptor the program draws on) and
 * told apart (a window system reads another program's, changes their
 * images' numbers and sends them on: TinyWindows.ml). Plan 9's twin is
 * libdraw, the library of the programs, where TinyGraphics.ml is the
 * kernel's draw device and libmemdraw; for C it is TinyKernel/user/
 * draw.h. In tiny-ml's ML and OCaml's, a file given to tiny-ml before
 * the program's own:
 *
 *     tiny-ml -tm -o windows.tm TinyDraw.ml TinyWindows.ml
 *
 * TinyGraphics.mli's header has the messages: a letter, then numbers
 * of 16 bits, the low byte first, signed.
 *
 * The way of a rectangle from a program to the screen, on the two
 * machines the same ML files run on:
 *
 *     a program            TinyTetris on TinyPlayground, TinyWindows
 *        | d_fill ...      this file: a string of 19 bytes
 *        | written on 3    tiny-machine: a system call (TinyKernel/
 *        |                 user's calls.ml); the host: TinyCalls, which
 *        |                 keeps it for a test
 *        | (a pipe, and TinyWindows renumbering, when in a window)
 *        | [messages]      TinyGraphics: in TinyKernel; on the host,
 *        |                 called by the test
 *        | pokeb, rows     tiny-machine: C and assembly (TinyKernel's
 *        |                 memory.ml); the host: TinyMemory, an array
 *     the screen's bytes   at 0xf00000 in both
 *
 * So the three files between a program and its machine (this one,
 * TinyCalls, TinyMemory) are where the host is put in the machine's
 * place, and all that is above them is tested by dune before
 * tiny-machine runs it.
 *
 * plan9-is-cleaner:
 * Drawing by writing bytes on a file is Plan 9's: its draw device is
 * a directory in /dev, and libdraw turns each call into a message, a
 * letter then numbers, written on a file of it; there d draws, f
 * frees an image, s is a string. Because
 * it is a file, it goes through a pipe or a network as any file
 * does, and a window system or a remote terminal needs no protocol
 * of its own. *)

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

(* [d_draw dst src mask x0 y0 x1 y1 px py], TinyGraphics's draw (-1: no
 * mask); a rectangle of a colour; a line; a text at a corner *)
val d_draw : int -> int -> int -> int -> int -> int -> int -> int -> int -> string
val d_fill : int -> int -> int -> int -> int -> int -> string
val d_line : int -> int -> int -> int -> int -> int -> string
val d_text : int -> int -> int -> int -> string -> string

(* the message at i of a string: its length (beyond the string's end
 * when it is not all there, -1 when it is no message) and how many of
 * its first numbers are images: what a window system renumbers *)
val d_shape : string -> int -> int * int
