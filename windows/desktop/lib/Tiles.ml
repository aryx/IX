(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tiles.mli *)

let label_h = 22
let margin = 16

let up a b = (a + b - 1) / b

let layout (area : Rectangle.t) sizes =
  let n = List.length sizes in
  if n = 0 then []
  else begin
    let cols = let rec go c = if c * c >= n then c else go (c + 1) in go 1 in
    let rows = up n cols in
    let cw = Rectangle.dx area / cols and ch = Rectangle.dy area / rows in
    List.mapi (fun i (w, h) ->
        let x0 = area.min.x + ((i mod cols) * cw) and y0 = area.min.y + ((i / cols) * ch) in
        let cell = Rectangle.v x0 y0 (x0 + cw) (y0 + ch) in
        let bw = max 1 (cw - (2 * margin)) and bh = max 1 (ch - (2 * margin) - label_h) in
        let k = max 1 (max (up (max 1 w) bw) (up (max 1 h) bh)) in
        let tw = w / k and th = h / k in
        let tx = x0 + ((cw - tw) / 2) and ty = y0 + margin + ((bh - th) / 2) in
        (cell, Rectangle.v tx ty (tx + tw) (ty + th), k))
      sizes
  end
