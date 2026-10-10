(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-colors: Plan 9's colors (principia's apps/misc/colors.c):
 * the 256 colours of Plan 9's colour map, a square each, 16 a row, the
 * last one first. The left button on a square says its number and its
 * red, green and blue; the right button's menu has exit. -r: a ramp of
 * 256 greys instead; -x: the numbers in hexadecimal.
 *
 * A graphical program like any: it draws where Display.screen says, in
 * its window under mini-rio (windows/), on the whole screen without.
 *
 * It is also the smallest program in ix that talks to the draw
 * device itself, and so the skeleton of all of them (mini-rio, the
 * Playground platform that mini-office runs on):
 *
 *   Display.init          the connection opened (/dev/draw)
 *   Display.color         a colour is an image: one pixel, repeated
 *   Display.screen        the image to draw in: the window's, or the
 *                         whole screen's
 *   Draw.fill             a message kept; nothing shows yet
 *   Display.flush         the messages sent: now it shows
 *   Mouse.receive         wait for the mouse; what comes says the
 *                         buttons, the place, and whether the window
 *                         was resized: then Display.screen again, and
 *                         everything painted again
 *
 * The map itself, worked on a few numbers ([cmap2rgb]): 0 is black
 * and 255 white; 0x00, 0x11, 0x22 and 0x33 are the four darkest
 * greys (0, 17, 34, 51), and there are sixteen greys in all, each a
 * multiple of 17. A number is a hue (four reds by four greens by
 * four blues, 64) and one of four values of it.
 *
 * design:
 * 256 colours, and how to spend them. The even way is a cube: six
 * levels each of red, green and blue is 216 colours, the palette the
 * web called safe, and it has six greys. Plan 9's map takes a
 * smaller cube, 64 hues, and gives each four levels of brightness,
 * because the eye tells two brightnesses apart much better than two
 * hues: a photograph reduced to it keeps its shading. The reasoning
 * is in the manual's color(6) (from memory).
 *
 * plan9-is-cleaner:
 * The loop repaints in one case only, a resize. A window covered and
 * uncovered needs nothing from the program: rio keeps each window's
 * pixels and puts them back itself. Under X a program is sent an
 * event for every part of its window that comes back into view and
 * must draw it again, so every program has that code; here the
 * resize is the one case left, and comes as one more thing read
 * from the mouse. *)

type caps = < Cap.draw; Cap.mouse; Cap.fork; Cap.stderr >

(* Plan 9's colour map (libdraw's cmap2rgb): a colour's number is two
 * bits of red, two of "value" (how bright), and four that are green
 * and blue once the first two are taken from them; the brightest of
 * the three is given the value, the others in proportion *)
let cmap2rgb c =
  let r = c lsr 6 and v = (c lsr 4) land 3 in
  let j = (c - v + r) land 15 in
  let g = j lsr 2 and b = j land 3 in
  let den = max r (max g b) in
  if den = 0 then v * 17, v * 17, v * 17
  else let num = 17 * ((4 * den) + v) in r * num / den, g * num / den, b * num / den

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let ramp = ref false and hex = ref false in
  let known = List.for_all (fun a -> match a with "-r" -> ramp := true; true | "-x" -> hex := true; true | "-rx" | "-xr" -> ramp := true; hex := true; true | _ -> false)
      (List.tl (Array.to_list argv)) in
  if not known then begin Console.eprint caps (Printf.sprintf "Usage: %s [-rx]\n" argv.(0)); Exit.Err "usage" end
  else begin
    let display = Display.init caps in
    let font = Font.default display and mouse = Mouse.init caps in
    let white = Display.color display Display.white and black = Display.color display Display.black in
    let rgb i = if !ramp then i, i, i else cmap2rgb i in
    let colors = Array.init 256 (fun i -> let r, g, b = rgb i in Display.color display (Display.rgb r g b)) in
    (* the squares: 16 rows of 16 under a line for the text, 5 pixels in, a pixel between two *)
    let square (view : Display.image) i : Rectangle.t =
      let r : Rectangle.t = Rectangle.inset view.r 5 in
      let top = r.min.y + 20 in
      let k = 255 - i in
      let x = k mod 16 and y = k / 16 in
      let at_x n = r.min.x + ((r.max.x - r.min.x) * n / 16) and at_y n = top + ((r.max.y - top) * n / 16) in
      Rectangle.inset (Rectangle.v (at_x x) (at_y y) (at_x (x + 1)) (at_y (y + 1))) 1 in
    let paint (view : Display.image) =
      Draw.fill view view.r white;
      Array.iteri (fun i c -> Draw.fill view (square view i) c) colors;
      Display.flush display in
    let say (view : Display.image) i =
      let cr, cg, cb = rgb i in
      let text =
        if !hex then Printf.sprintf "index %2X r %3X g %3X b %3X 0x%02X%02X%02XFF       " i cr cg cb cr cg cb
        else Printf.sprintf "index %3d r %3d g %3d b %3d 0x%02X%02X%02XFF        " i cr cg cb cr cg cb in
      let p : Point.t = Point.add view.r.min (Point.v 2 2) in
      Draw.fill view (Rectangle.v p.x p.y (p.x + Font.width font text) (p.y + Font.height font)) white;
      ignore (Font.string view p black font text);
      Display.flush display in
    let rec loop view shown =
      let m : Mouse.state = Event.sync (Mouse.receive mouse) in
      (* its window moved or made another size: the squares again, in the new one *)
      if m.resized then begin let view = Display.screen display in paint view; loop view None end
      else if m.buttons = 1 then begin
        let rec find i = if i = 256 then None else if Rectangle.contains (square view i) m.pos then Some i else find (i + 1) in
        match find 0 with
        | Some i when Some i <> shown -> say view i; loop view (Some i)
        | _ -> loop view shown
      end
      else if m.buttons = 4 then (match Menu.hit view font mouse 4 [ "exit" ] 0 m.pos with Some _ -> () | None -> loop view shown)
      else loop view shown in
    let view = Display.screen display in
    paint view;
    loop view None;
    Exit.OK
  end

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
