(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLibDraw.mli *)

(* a number's two bytes (each byte's string made once: old, two
 * String.make a number, and a window's program spent half its time
 * making messages); the number at i of s *)
let bytes = Array.make 256 ""
let () = for c = 0 to 255 do bytes.(c) <- String.make 1 (Char.chr c) done
(* (and the two bytes of each number from 0 to 1024, a coordinate or an
 * image's number, made once: a message was two concatenations a
 * number, half of what a browser's page down cost in the program) *)
let small = Array.make 1025 ""
let () =
  for v = 0 to 1024 do
    small.(v) <- bytes.(v land 255) ^ bytes.((v asr 8) land 255)
  done
let i16 v =
  if v >= 0 && v <= 1024 then small.(v)
  else bytes.(v land 255) ^ bytes.((v asr 8) land 255)
let int16 s i =
  let v = Char.code s.[i] + (256 * Char.code s.[i + 1]) in
  if v >= 32768 then v - 65536 else v

(* tiny-machine's screen (TinyMachineDevices'), in pixels *)
let screen_w = 1024
let screen_h = 768

(* a message: its letter, its numbers *)
let msg letter args =
  List.fold_left (fun s v -> s ^ i16 v) bytes.(Char.code letter) args

(* See TinyLibDraw.mli for the types' names *)
type image = int
type pixel = int
type rect = int * int * int * int
type point = int * int
type style = int
type cursor = Cursor_arrow | Cursor_hand

(* an image of that rectangle, filled with a colour's byte (the one
 * that had this number freed); a colour: one pixel, repeating *)
let d_image (id : image) ((x0, y0, x1, y1) : rect) (colour : pixel) =
  msg 'a' [ id; x0; y0; x1; y1; 0; colour ]
let d_colour (id : image) (colour : pixel) =
  msg 'a' [ id; 0; 0; 1; 1; 1; colour ]
let d_free (id : image) = msg 'f' [ id ]

(* dst's rectangle: src's pixels from (px, py) on, where mask's are
 * set (-1: no mask); a rectangle of a colour *)
let d_draw (dst : image) (src : image) (mask : image)
    ((x0, y0, x1, y1) : rect) ((px, py) : point) =
  msg 'd' [ dst; src; mask; x0; y0; x1; y1; px; py ]
let d_fill dst src (r : rect) = d_draw dst src (-1) r (0, 0)

(* a line, both ends drawn; a text (a character is 8 by 16), its top
 * left corner at (x, y) *)
let d_line (dst : image) (src : image) ((xa, ya) : point) ((xb, yb) : point) =
  msg 'l' [ dst; src; xa; ya; xb; yb ]
let d_ellipse (dst : image) (src : image) ((cx, cy) : point) a b =
  msg 'e' [ dst; src; cx; cy; a; b ]
let d_fill_ellipse (dst : image) (src : image) ((cx, cy) : point) a b =
  msg 'E' [ dst; src; cx; cy; a; b ]
let d_fill_polygon (dst : image) (src : image) (points : point list) =
  List.fold_left (fun s (x, y) -> s ^ i16 x ^ i16 y)
    (msg 'P' [ dst; src; List.length points ]) points
let d_text (dst : image) (src : image) ((x, y) : point) s =
  msg 's' [ dst; src; x; y; String.length s ] ^ s
let d_styled (dst : image) (src : image) ((x, y) : point) (style : style) s =
  msg 't' [ dst; src; x; y; String.length s; style ] ^ s

(* a row of pixels, a byte each, its left end at (x, y) *)
let d_pixels (dst : image) ((x, y) : point) s =
  msg 'p' [ dst; x; y; String.length s ] ^ s

(* the mouse's look, 0 or 1 on the wire *)
let d_cursor c = msg 'c' [ (match c with Cursor_arrow -> 0 | Cursor_hand -> 1) ]

(* The mouse as the kernel's descriptor 4 says it, 12 bytes: where it
 * is and its buttons, three numbers of two bytes, each followed by two
 * bytes of nothing; None when it is not all there. A window's mouse is
 * 16 bytes, tiny-windows's: the window's width and height after them,
 * in each message (a box keeps the last one only), so a window given
 * another size is known at its next mouse *)
type mouse_event = {
  mo_x : int; mo_y : int; mo_buttons : int; mo_size : (int * int) option
}
let mouse_event (s : string) : mouse_event option =
  let n = String.length s in
  if n <> 12 && n <> 16 then None
  else
    Some { mo_x = int16 s 0; mo_y = int16 s 4; mo_buttons = int16 s 8;
           mo_size = if n = 16 then Some (int16 s 12, int16 s 14) else None }

(* The message at i of s: its length, and how many of its first numbers
 * are images. The length is beyond s's end when the message is not all
 * there yet (a pipe gives what it has), and -1 when this is no message. *)
type message_shape = { ds_length : int; ds_images : int }

let shape s i =
  match s.[i] with
  | 'a' -> 15, 1
  | 'f' -> 3, 1
  | 'd' -> 19, 3
  | 'l' | 'e' | 'E' -> 13, 2
  | 's' ->
      if i + 11 > String.length s then 11, 2
      else if int16 s (i + 9) < 0 then -1, 0
      else 11 + int16 s (i + 9), 2
  | 't' ->
      if i + 13 > String.length s then 13, 2
      else if int16 s (i + 9) < 0 then -1, 0
      else 13 + int16 s (i + 9), 2
  | 'p' ->
      if i + 9 > String.length s then 9, 1
      else if int16 s (i + 7) < 0 then -1, 0
      else 9 + int16 s (i + 7), 1
  | 'P' ->
      if i + 7 > String.length s then 7, 2
      else if int16 s (i + 5) < 0 then -1, 0
      else 7 + (4 * int16 s (i + 5)), 2
  | 'c' -> 3, 0
  | _ -> -1, 0

let d_shape s i : message_shape =
  let (length, images) = shape s i in
  { ds_length = length; ds_images = images }
