(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

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
 * TinyGraphics.ml's header has the messages: a letter, then numbers
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
 * frees an image, s is a string (the letters from memory). Because
 * it is a file, it goes through a pipe or a network as any file
 * does, and a window system or a remote terminal needs no protocol
 * of its own. *)

(* a number's two bytes (each byte's string made once: old, two
 * String.make a number, and a window's program spent half its time
 * making messages); the number at i of s *)
let bytes = Array.make 256 ""
let () = for c = 0 to 255 do bytes.(c) <- String.make 1 (Char.chr c) done
let i16 v = bytes.(v land 255) ^ bytes.((v asr 8) land 255)
let int16 s i = let v = Char.code s.[i] + (256 * Char.code s.[i + 1]) in if v >= 32768 then v - 65536 else v

(* a message: its letter, its numbers *)
let msg letter args = List.fold_left (fun s v -> s ^ i16 v) bytes.(Char.code letter) args

(* an image of that rectangle, filled with a colour's byte (the one
 * that had this number freed); a colour: one pixel, repeating *)
let d_image id x0 y0 x1 y1 colour = msg 'a' [ id; x0; y0; x1; y1; 0; colour ]
let d_colour id colour = msg 'a' [ id; 0; 0; 1; 1; 1; colour ]
let d_free id = msg 'f' [ id ]

(* dst's rectangle: src's pixels from (px, py) on, where mask's are
 * set (-1: no mask); a rectangle of a colour *)
let d_draw dst src mask x0 y0 x1 y1 px py = msg 'd' [ dst; src; mask; x0; y0; x1; y1; px; py ]
let d_fill dst src x0 y0 x1 y1 = d_draw dst src (-1) x0 y0 x1 y1 0 0

(* a line, both ends drawn; a text (a character is 8 by 16), its top
 * left corner at (x, y) *)
let d_line dst src xa ya xb yb = msg 'l' [ dst; src; xa; ya; xb; yb ]
let d_text dst src x y s = msg 's' [ dst; src; x; y; String.length s ] ^ s

(* The message at i of s: its length, and how many of its first numbers
 * are images. The length is beyond s's end when the message is not all
 * there yet (a pipe gives what it has), and -1 when this is no message. *)
let d_shape s i =
  match s.[i] with
  | 'a' -> 15, 1
  | 'f' -> 3, 1
  | 'd' -> 19, 3
  | 'l' -> 13, 2
  | 's' -> if i + 11 > String.length s then 11, 2 else if int16 s (i + 9) < 0 then -1, 0 else 11 + int16 s (i + 9), 2
  | _ -> -1, 0
