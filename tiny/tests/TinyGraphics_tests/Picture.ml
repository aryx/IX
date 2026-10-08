(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* TinyGraphics.ml's test: a picture on the screen, all of it drawn by
 * messages, and what the bad ones are answered. In tiny-ml's ML and
 * OCaml's: TinyGraphics_test.sh runs it on the host (Host.ml) and on
 * tiny-machine (machine.ml), for the same screen and the same lines. *)

open TinyGraphics

(* a message: its letter, its numbers (16 bits, the low byte first) *)
let i16 v = String.make 1 (Char.chr (v land 255)) ^ String.make 1 (Char.chr ((v asr 8) land 255))
let msg letter args = List.fold_left (fun s v -> s ^ i16 v) (String.make 1 letter) args
let colour id v = msg 'a' [ id; 0; 0; 1; 1; 1; v ]
let image id x0 y0 x1 y1 v = msg 'a' [ id; x0; y0; x1; y1; 0; v ]
let draw_ dst src mask x0 y0 x1 y1 px py = msg 'd' [ dst; src; mask; x0; y0; x1; y1; px; py ]
let fill dst src x0 y0 x1 y1 = draw_ dst src (-1) x0 y0 x1 y1 0 0
let line_ dst src xa ya xb yb = msg 'l' [ dst; src; xa; ya; xb; yb ]
let text_ dst src x y s = msg 's' [ dst; src; x; y; String.length s ] ^ s

(* the font's bits are at [bits]; the screen at its address, the
 * images' memory after it, to the last page *)
let picture bits =
  arena 0xf4b000 0xb4000;
  let screen = { r = rect 0 0 640 480; at = 0xf00000; repl = false } in
  let c = connect screen (font_mask bits (alloc 16384)) in
  let send s = messages c s in
  let grey = 1 and blue = 2 and white = 3 and black = 4 and red = 5 and yellow = 6 and green = 7 in
  send (colour grey 0xaa ^ colour blue 0x36 ^ colour white 255 ^ colour black 0 ^ colour red 0xf0 ^ colour yellow 0xfc ^ colour green 0x3f);
  (* rectangles: whole, off the screen's corners, of no pixel *)
  send (fill 0 grey 0 0 640 480 ^ fill 0 blue 40 40 200 120 ^ fill 0 red (-30) (-20) 60 30 ^ fill 0 yellow 600 440 700 500 ^
        fill 0 red 300 300 290 310);
  (* texts: whole, cut by the screen's right side and its top, a byte that is no character *)
  send (text_ 0 white 48 48 "TinyGraphics" ^ text_ 0 black 48 72 "one operation: draw" ^
        text_ 0 black 540 200 "cut by the side" ^ text_ 0 yellow 300 (-8) "cut by the top" ^ text_ 0 red 48 96 "caf\233!");
  (* lines from the middle: each way, to the corners, off the screen, a point *)
  List.iter (fun (x, y) -> send (line_ 0 black 320 240 x y)) [ 20, 140; 120, 470; 639, 479; 700, 300; 320, 130 ];
  List.iter (fun (x, y) -> send (line_ 0 black 320 240 x y)) [ 520, 240; 0, 0; 400, 200; 330, 470; 320, 240 ];
  (* an image off the screen (a window): drawn in, then on the screen, whole, cut, and from a point of it *)
  send (image 10 0 0 120 60 0x3f ^ line_ 10 black 0 0 119 0 ^ line_ 10 black 119 0 119 59 ^ line_ 10 black 119 59 0 59 ^
        line_ 10 black 0 59 0 0 ^ text_ 10 black 8 8 "a window" ^ fill 10 blue 20 34 100 50 ^ text_ 10 white 24 34 "of ML" ^
        draw_ 0 10 (-1) 240 20 360 80 0 0 ^ draw_ 0 10 (-1) 580 20 700 80 0 0 ^ draw_ 0 10 (-1) 400 300 600 400 30 10);
  (* an image whose corner is not the origin *)
  send (image 11 100 100 140 130 0xfc ^ line_ 11 red 100 100 139 129 ^ draw_ 0 11 (-1) 400 40 440 70 100 100);
  (* a pattern: two pixels by two, repeating; as a source, from two points, and as a mask *)
  send (msg 'a' [ 12; 0; 0; 2; 2; 1; 255 ] ^ fill 12 black 0 0 1 1 ^ fill 12 black 1 1 2 2 ^
        fill 0 12 40 300 140 380 ^ draw_ 0 12 (-1) 150 300 250 380 1 0 ^ draw_ 0 red 12 40 390 140 440 0 0);
  (* an image through a mask that is no pattern: a hole of 60 by 30 *)
  send (image 13 0 0 120 60 0 ^ fill 13 white 30 15 90 45 ^ draw_ 0 10 13 150 390 270 450 0 0);
  (* an image drawn on itself, each way (a text scrolled), shown after each *)
  send (draw_ 10 10 (-1) 0 0 120 55 0 5 ^ draw_ 0 10 (-1) 500 100 620 160 0 0 ^
        draw_ 10 10 (-1) 0 7 120 60 0 0 ^ draw_ 0 10 (-1) 500 170 620 230 0 0 ^
        draw_ 10 10 (-1) 9 0 120 60 0 0 ^ draw_ 0 10 (-1) 500 240 620 300 0 0 ^
        draw_ 10 10 (-1) 0 0 109 60 11 0 ^ draw_ 0 10 (-1) 500 310 620 370 0 0);
  (* an image freed, its memory another's *)
  send (msg 'f' [ 10 ] ^ image 14 0 0 60 120 0xf0 ^ text_ 14 white 6 50 "again" ^ draw_ 0 14 (-1) 570 350 630 470 0 0);
  (* the bad messages, each said; the ones before it in its write are done
   * (the lists are short and a write is messages joined: tiny-ml -tm has
   * 11 registers for an expression, and a list's elements are one) *)
  let bad s = try send s; print_string "taken\n" with Graphics why -> print_string (why ^ "\n") in
  bad "z"; bad (fill 0 white 0 470 10 480 ^ "d\001"); bad (fill 0 9 0 0 10 10); bad (draw_ 0 white 9 0 0 10 10 0 0);
  bad (msg 'f' [ 0 ]); bad (msg 'f' [ 10 ]); bad (colour 14 0); bad (image 15 0 0 0 10 0); bad (image 15 0 0 3000 10 0);
  bad (image 15 0 0 1024 1024 0); bad (text_ 0 white 0 0 "cut" ^ "\005"); bad (msg 's' [ 0; white; 0; 0; 9 ] ^ "short");
  bad (fill 0 green 10 470 20 480);
  (* the connection's end: the memory one block again, but the font *)
  disconnect c;
  List.iter (fun (a, n) -> print_string ("free: " ^ string_of_int n ^ " bytes at " ^ string_of_int (a - 0xf4b000) ^ "\n")) !blocks
