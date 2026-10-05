(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Menu.mli *)

(* menuhit's: the box's border, the space around the items, between two *)
let border = 2 and margin = 4 and spacing = 2

let hit (screen : Display.image) font mouse button items last (at : Point.t) =
  let d = screen.display in
  let color r g b = Display.color d (Display.rgb r g b) in
  (* ix's colours, blues (Plan 9's menuhit has greens: one sees whose menu it is) *)
  let back = color 0xea 0xf2 0xff and edge = color 0x88 0xaa 0xcc and high = color 0x33 0x66 0x99 and text = color 0 0 0 in
  let n = List.length items in
  let item_h = Font.height font + spacing in
  let w = List.fold_left (fun w s -> max w (Font.width font s)) 0 items + (2 * (margin + border)) in
  let h = (n * item_h) + (2 * (margin + border)) in
  (* the last choice under the mouse; all of it on the screen *)
  let x = at.x - (w / 2) and y = at.y - (border + margin + (last * item_h) + (item_h / 2)) in
  let x = max screen.r.min.x (min x (screen.r.max.x - w)) and y = max screen.r.min.y (min y (screen.r.max.y - h)) in
  let r = Rectangle.v x y (x + w) (y + h) in
  let item_r k = Rectangle.v (x + border) (y + border + margin + (k * item_h)) (x + w - border) (y + border + margin + ((k + 1) * item_h)) in
  let under (p : Point.t) = if Rectangle.contains (Rectangle.inset r border) p then let k = (p.y - (y + border + margin)) / item_h in if k >= 0 && k < n && p.y >= y + border + margin then Some k else None else None in
  (* what the menu covers, kept *)
  let saved = Display.alloc d r "r8g8b8" ~repl:false Display.black in
  Draw.draw saved r screen None r.min;
  let paint chosen =
    Draw.fill screen r back;
    Draw.border screen r border edge;
    List.iteri (fun k s ->
      let ir = item_r k in
      if chosen = Some k then Draw.fill screen ir high;
      ignore (Font.string screen (Point.v (ir.min.x + ((Rectangle.dx ir - Font.width font s) / 2)) (ir.min.y + (spacing / 2)))
                (if chosen = Some k then back else text) font s)) items;
    Display.flush d in
  let rec follow chosen =
    let m : Mouse.state = Event.sync (Mouse.receive mouse) in
    if m.buttons land button = 0 then under m.pos
    else begin
      let now = under m.pos in
      if now <> chosen then paint now;
      follow now
    end in
  let first = under at in
  paint first;
  let choice = follow first in
  Draw.draw screen r saved None r.min;
  Display.free saved;
  List.iter Display.free [ back; edge; high; text ];
  Display.flush d;
  choice
