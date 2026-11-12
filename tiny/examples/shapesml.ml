(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* shapesml: shapes.c's picture in ML. Each TinyLibDraw.d_ function is a
 * message, a string; the program joins them and writes them on its
 * descriptor 3 (TinyLibSystem.fd_draw), the screen, or its window when
 * windows runs it; then a key quits. It links TinyLibSystem and
 * TinyLibDraw, from /lib/ml (the Buildfile beside it):
 *
 *	cd /examples; build shapesml; ./shapesml
 *)
module D = TinyLibDraw
module TSys = TinyLibSystem

(* a colour is an image of one pixel, its number the program's own *)
let grey = 1
let black = 2
let red = 3
let blue = 4
let yellow = 5
let white = 6

(* a fan of lines from a corner, the i-th and the ones after it *)
let rec fan i =
  if i > 8 then ""
  else D.d_line 0 black (320, 440) (320 + (40 * i), 300) ^ fan (i + 1)

let picture =
  String.concat ""
    [ D.d_colour grey 0xaa; D.d_colour black 0; D.d_colour red 0xf0;
      D.d_colour blue 0x36; D.d_colour yellow 0xfc; D.d_colour white 255;
      D.d_fill 0 grey (0, 0, D.screen_w, D.screen_h);
      D.d_fill 0 blue (0, 0, D.screen_w, 20);
      D.d_text 0 white (8, 2) "shapesml: a key quits";
      (* a red square in a black frame, and the sun *)
      D.d_fill 0 black (96, 96, 264, 264);
      D.d_fill 0 red (100, 100, 260, 260);
      D.d_fill 0 yellow (400, 80, 480, 160);
      fan 0;
      D.d_text 0 black (100, 280) "hello, world, in pixels" ]

let () =
  TSys.main "shapesml" (fun _ _ ->
      TSys.write TSys.fd_draw picture;
      ignore (TSys.read TSys.fd_stdin 1);
      Exit.OK)
