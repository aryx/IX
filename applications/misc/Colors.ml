(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-colors: Plan 9's colors (principia's applications/misc/colors.c):
 * the 256 colours of Plan 9's colour map, a square each, 16 a row, the
 * last one first. The left button on a square says its number and its
 * red, green and blue; the right button's menu has exit. -r: a ramp of
 * 256 greys instead; -x: the numbers in hexadecimal.
 *
 * A graphical program like any: it draws where Display.screen says, in
 * its window under mini-rio (windows/), on the whole screen without. *)

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
    let view = Display.screen display and font = Font.default display and mouse = Mouse.init caps in
    let white = Display.color display Display.white and black = Display.color display Display.black in
    let rgb i = if !ramp then i, i, i else cmap2rgb i in
    let colors = Array.init 256 (fun i -> let r, g, b = rgb i in Display.color display (Display.rgb r g b)) in
    (* the squares: 16 rows of 16 under a line for the text, 5 pixels in, a pixel between two *)
    let r : Rectangle.t = Rectangle.inset view.r 5 in
    let top = r.min.y + 20 in
    let square i : Rectangle.t =
      let k = 255 - i in
      let x = k mod 16 and y = k / 16 in
      let at_x n = r.min.x + ((r.max.x - r.min.x) * n / 16) and at_y n = top + ((r.max.y - top) * n / 16) in
      Rectangle.inset (Rectangle.v (at_x x) (at_y y) (at_x (x + 1)) (at_y (y + 1))) 1 in
    Draw.fill view view.r white;
    Array.iteri (fun i c -> Draw.fill view (square i) c) colors;
    Display.flush display;
    let say i =
      let cr, cg, cb = rgb i in
      let text =
        if !hex then Printf.sprintf "index %2X r %3X g %3X b %3X 0x%02X%02X%02XFF       " i cr cg cb cr cg cb
        else Printf.sprintf "index %3d r %3d g %3d b %3d 0x%02X%02X%02XFF        " i cr cg cb cr cg cb in
      let p : Point.t = Point.add view.r.min (Point.v 2 2) in
      Draw.fill view (Rectangle.v p.x p.y (p.x + Font.width font text) (p.y + Font.height font)) white;
      ignore (Font.string view p black font text);
      Display.flush display in
    let rec loop shown =
      let m : Mouse.state = Event.sync (Mouse.receive mouse) in
      if m.buttons = 1 then begin
        let rec find i = if i = 256 then None else if Rectangle.contains (square i) m.pos then Some i else find (i + 1) in
        match find 0 with
        | Some i when Some i <> shown -> say i; loop (Some i)
        | _ -> loop shown
      end
      else if m.buttons = 4 then (match Menu.hit view font mouse 4 [ "exit" ] 0 m.pos with Some _ -> () | None -> loop shown)
      else loop shown in
    loop None;
    Exit.OK
  end

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
