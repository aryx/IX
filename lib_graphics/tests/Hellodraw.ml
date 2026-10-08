(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* hellodraw: lib_graphics's first program (plan_rio.md, stage 7a), the
 * author's hellodraw.c (principia's lib_graphics/libdraw/tests) and
 * hellodraw.ml (xix's lib_graphics/draw/tests) with ix's library: the
 * display opened, the screen made magenta, a thick line, a line of
 * text in Plan 9's default font. kernels/9pi's make check-draw runs it
 * on mini-9pi and compares the screen. *)

let main (caps : < Cap.draw; .. >) : Exit.t =
  let display = Display.init caps in
  let view = Display.screen display in
  let black = Display.color display Display.black and font = Font.default display in
  Draw.fill view view.r (Display.color display (Display.rgb 0xff 0x00 0xff));
  Draw.line view (Point.v 10 10) (Point.v 100 100) 10 black;
  ignore (Font.string view (Point.v 200 200) black font "Hello Graphical World");
  Display.flush display;
  Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
