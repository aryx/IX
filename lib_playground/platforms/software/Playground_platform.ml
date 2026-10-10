(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The platform that computes its pixels, on Plan 9 (mini-9pi; in a
 * window of mini-rio's or on the bare screen): docs/plans/plan_playground.md,
 * stage 2. The playground's software platform, SDL's window become the
 * draw device's.
 *
 * A frame is drawn by the program, in its own memory
 * (Shape_render_software, in a Framebuffer: lib_graphics/software), and
 * given to the device as a picture: the bytes loaded into an image of
 * the kernel's (Display.load), which is then drawn on the window
 * (Draw.draw) and shown (Display.flush). The device draws nothing but
 * that: the other platform (../draw) asks it for each shape.
 *
 * Not the whole picture each time: the parts of it that changed since
 * the frame before (Redraw). A whole frame of 480 by 480 is a second
 * under QEMU (the shapes 0.6 s, the load 0.2), and a key waited for it.
 *
 * The picture is a square, the playground's 1000 units on the smaller
 * of the window's sides, in its middle.
 *
 * The loop is Plan9_loop's (the clock, the keys, the mouse: the same
 * for the platform that asks the device for each shape).
 *
 * The clock. A program's Tick is a sixtieth of a second of its world,
 * whatever the machine (a piece of Tetris falls by ticks): so the ticks
 * due since the start are counted on the system's clock and all given,
 * then one frame is drawn. A machine that draws 5 frames a second plays
 * the same game as one that draws 60, less smoothly.
 *
 * The keys. Plan 9's console gives characters, as they are typed, and
 * no key's release. Where there is a /dev/kbd (mini-9pi's, and a window
 * of mini-rio's: the keys down, at each change), a key is down and up
 * as it is, and the console's characters are only what was typed
 * (Sub.on_typed). Where there is none, a key is down from its character
 * to the next tick: enough for a program that asks for presses, not for
 * one that asks whether a key is held. Ctrl-Q ends the program, as on
 * the playground's platforms, and so does Delete.
 *
 * usage: game [-frames n [-script script] [-fixed-time seconds]] [name=value]...
 *   redraw=all  (a flag) each frame drawn whole, not what changed only:
 *               to see what Redraw saves
 *   -frames n   n frames at once, the script's keys in them, then the
 *               picture stays: a session that is the same each time,
 *               for a test to compare its screen (Session.mli) *)

(* where the program draws: the window, the picture's square in it, the
 * kernel's image the program's pixels are loaded into, and what was
 * drawn last (Redraw: a frame is the parts that changed) *)
type window = { view : Display.image; at : Rectangle.t; image : Display.image; redraw : Redraw.t; size : int; scale : float }

let window (display : Display.t) : window =
  let view = Display.screen display in
  let w = Rectangle.dx view.r and h = Rectangle.dy view.r in
  let n = max 1 (min w h) in
  let x = view.r.min.x + ((w - n) / 2) and y = view.r.min.y + ((h - n) / 2) in
  let white = Display.color display Display.white in
  Draw.fill view view.r white;
  Display.free white;
  let scale = float n /. Playground.default_width in
  let options = { Shape_render_software.default_options with antialiasing = Playground.default_rendering.antialiasing } in
  { view; at = Rectangle.v x y (x + n) (y + n); size = n; scale;
    image = Display.alloc display (Rectangle.v 0 0 n n) "x8r8g8b8" ~repl:false Display.white;
    redraw = Redraw.create ~width:n ~height:n ~scale options }

(* a frame: its parts that changed drawn here, each loaded into the
 * kernel's image where it goes, and that rectangle of the image drawn
 * on the window *)
let show (display : Display.t) (win : window) (shapes : Playground.shape list) (fps : int) : bool =
  let counter = Session.fps_counter ~width:win.size ~height:win.size ~scale:win.scale fps in
  let parts = Redraw.frame win.redraw (shapes @ [ counter ]) in
  List.iter
    (fun (((x0, y0, x1, _), fb) : (int * int * int * int) * Framebuffer.t) ->
      let w = x1 - x0 in
      (* (one message, one write, whatever its size: the first version
       * gave the rows 60,000 bytes at a time, a copy made of each) *)
      Display.load_sub win.image (Rectangle.v x0 y0 x1 (y0 + fb.height)) fb.pixels 0 (4 * w * fb.height);
      let corner : Point.t = Point.v (win.at.min.x + x0) (win.at.min.y + y0) in
      Draw.draw win.view (Rectangle.v corner.x corner.y (corner.x + w) (corner.y + fb.height)) win.image None (Point.v x0 y0))
    parts;
  if parts <> [] then Display.flush display;
  parts <> []

let flags = Plan9_loop.flags

(* Plan 9's cursor is a picture written to /dev/cursor: not yet *)
let set_cursor (_ : Playground.cursor) : unit = ()

let run_app (caps : < Cap.argv ; Cap.draw ; Cap.mouse ; Cap.keyboard ; Cap.fork ; Cap.open_out ; .. >) (flags : Playground.flags)
    (app : ('model, 'msg) Playground.app) : unit =
  (* (the flag redraw=all: each frame the whole picture, the simple way) *)
  if List.assoc_opt "redraw" (Plan9_loop.flags caps) = Some "all" then Redraw.enabled := false;
  Plan9_loop.run_app
    { Plan9_loop.make = window; at = (fun (w : window) -> w.at); show; free = (fun (w : window) -> Display.free w.image) }
    caps flags app
