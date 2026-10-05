(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* hellorio: a program that draws in a window (plan_rio.md, stage 7c),
 * the author's hellorio.c (principia's windows/rio/tests) and
 * hellorio.ml (xix's windows/tests) with ix's libraries: its window
 * made magenta, "Hello Rio" where the mouse is, the last keys typed;
 * q ends it. It knows nothing of windows: it opens /dev/draw,
 * /dev/mouse and /dev/cons, which in a window are the window's (the
 * window system's files; Display.screen asks /dev/winname where to
 * draw). On the bare screen it runs the same. *)

type caps = < Cap.draw; Cap.mouse; Cap.keyboard; Cap.fork >

type event = Mouse of Mouse.state | Keys of string

let main (caps : < caps; .. >) : Exit.t =
  let display = Display.init caps in
  let font = Font.default display in
  let mouse = Mouse.init caps and keyboard = Keyboard.init caps in
  let magenta = Display.color display (Display.rgb 0xff 0x00 0xff) and black = Display.color display Display.black in
  let redraw (view : Display.image) (at : Point.t) keys =
    Draw.fill view view.r magenta;
    if Rectangle.contains view.r at then ignore (Font.string view at black font "Hello Rio");
    ignore (Font.string view (Point.add view.r.min (Point.v 8 8)) black font ("keys: " ^ String.escaped keys));
    Display.flush display in
  let rec loop view at keys =
    redraw view at keys;
    match Event.select [ Event.wrap (Mouse.receive mouse) (fun m -> Mouse m); Event.wrap (Keyboard.receive keyboard) (fun k -> Keys k) ] with
    | Keys k when String.contains k 'q' -> ()
    | Keys k -> loop view at k
    (* its window moved or made another size: where to draw, asked again *)
    | Mouse m when m.resized -> loop (Display.screen display) m.pos keys
    | Mouse m -> loop view m.pos keys in
  let view = Display.screen display in
  loop view (Point.add view.r.min (Point.v 60 60)) "";
  Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps)))
