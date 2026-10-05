(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Font.mli *)

(* a character in the font's image: its first column there (the next
 * one's is its end), the rows it has pixels on, how far right of the
 * pen it starts, and how far the pen moves *)
type glyph = { x : int; top : int; bottom : int; left : int; advance : int }

type t = { image : Display.image; height : int; ascent : int; glyphs : glyph array }

let height (f : t) = f.height
let ascent (f : t) = f.ascent

(* The bytes: an image as Plan 9 wrote them once, five numbers of 12
 * characters (the depth, 0: a bit a pixel; the rectangle) and its rows
 * of pixels; then a subfont, three numbers (how many characters, the
 * height, the ascent) and for each character and one more six bytes:
 * x (2), top, bottom, left, width. *)
let default (d : Display.t) =
  let s = Font_default.data in
  let num o = int_of_string (String.trim (String.sub s o 12)) in
  let r = Rectangle.v (num 12) (num 24) (num 36) (num 48) in
  let row = (Rectangle.dx r + 7) / 8 in
  let pixels = String.sub s 60 (row * Rectangle.dy r) in
  let o = 60 + String.length pixels in
  let n = num o and height = num (o + 12) and ascent = num (o + 24) in
  let glyphs = Array.init (n + 1) (fun k ->
    let g = o + 36 + (6 * k) in
    let b j = Char.code s.[g + j] in
    { x = b 0 lor (b 1 lsl 8); top = b 2; bottom = b 3; left = (if b 4 > 127 then b 4 - 256 else b 4); advance = b 5 }) in
  let image = Display.alloc d r "k1" ~repl:false Display.black in
  Display.load image r pixels;
  { image; height; ascent; glyphs }

let width (f : t) s =
  let w = ref 0 in
  String.iter (fun c -> let k = Char.code c in if k < Array.length f.glyphs - 1 then w := !w + f.glyphs.(k).advance) s;
  !w

let string (dst : Display.image) (p : Point.t) color (f : t) s =
  let x = ref p.x in
  String.iter (fun c ->
    let k = Char.code c in
    if k < Array.length f.glyphs - 1 then begin
      let g = f.glyphs.(k) in
      let w = f.glyphs.(k + 1).x - g.x in
      if w > 0 then
        Draw.draw_mask dst (Rectangle.v (!x + g.left) (p.y + g.top) (!x + g.left + w) (p.y + g.bottom)) color Point.zero f.image (Point.v g.x g.top);
      x := !x + g.advance
    end) s;
  Point.v !x p.y
