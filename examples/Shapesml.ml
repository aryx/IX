(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* shapesml: a picture drawn on mini-9pi's screen, or in its window
 * under rio, with lib_graphics's client of the draw device (Display,
 * Draw, Font, after Plan 9's libdraw). A colour is an image of one
 * pixel that repeats; each Draw function is a message to /dev/draw,
 * kept until Display.flush sends them all; then a key quits. It knows
 * nothing of windows: in a window, /dev/draw and /dev/cons are the
 * window's (windows/rio/tests/Hellorio.ml also follows the mouse and
 * a window made another size). For mini-9pi only, Linux having no draw
 * device. The mkfile beside it builds it, with lib_graphics:
 *
 *     cd /src/examples; mk; ../_mk/5-plan9/examples/shapesml
 *)

type caps = < Cap.draw; Cap.keyboard; Cap.fork >

let main (caps : < caps; .. >) : Exit.t =
  let display = Display.init caps in
  let keyboard = Keyboard.init caps in
  let view = Display.screen display in
  let font = Font.default display in
  let colour r g b = Display.color display (Display.rgb r g b) in
  let grey = colour 0xaa 0xaa 0xaa and black = colour 0 0 0 in
  let red = colour 0xe0 0x30 0x30 and blue = colour 0x30 0x50 0xc0 in
  let yellow = colour 0xf0 0xd0 0x30 and white = colour 0xff 0xff 0xff in
  (* a place in the picture, from the corner of the screen or the window *)
  let at x y = Point.add view.r.min (Point.v x y) in
  let box x0 y0 x1 y1 : Rectangle.t = { min = at x0 y0; max = at x1 y1 } in
  Draw.fill view view.r grey;
  Draw.fill view (box 0 0 (Rectangle.dx view.r) 20) blue;
  ignore (Font.string view (at 8 2) white font "shapesml: a key quits");
  (* a red square in a black frame, the sun, and a fan of lines *)
  Draw.fill view (box 96 96 264 264) red;
  Draw.border view (box 96 96 264 264) 4 black;
  Draw.fillellipse view (at 440 120) 40 40 yellow;
  for i = 0 to 8 do
    Draw.line view (at 320 440) (at (320 + (40 * i)) 300) 1 black
  done;
  ignore (Font.string view (at 100 280) black font "hello, world, in pixels");
  Display.flush display;
  ignore (Event.sync (Keyboard.receive keyboard));
  Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
