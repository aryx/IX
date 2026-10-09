(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Picture.mli *)

type t = { w : int; h : int; pixels : Bytes.t }

let create (w : int) (h : int) : t = { w; h; pixels = Bytes.make (3 * w * h) '\000' }

let set (p : t) (x : int) (y : int) ((r, g, b) : Cells.rgb) : unit =
  if x >= 0 && x < p.w && y >= 0 && y < p.h then begin
    let o = 3 * ((y * p.w) + x) in
    Bytes.unsafe_set p.pixels o (Char.unsafe_chr r);
    Bytes.unsafe_set p.pixels (o + 1) (Char.unsafe_chr g);
    Bytes.unsafe_set p.pixels (o + 2) (Char.unsafe_chr b)
  end

let fill (p : t) ((x0, y0, x1, y1) : int * int * int * int) (c : Cells.rgb) : unit =
  for y = max 0 y0 to min p.h y1 - 1 do
    for x = max 0 x0 to min p.w x1 - 1 do set p x y c done
  done

(*****************************************************************************)
(* The font *)
(*****************************************************************************)

(* a character in the font's image: Font's glyph *)
type glyph = { x : int; top : int; bottom : int; left : int; advance : int }

(* the image's rows of bits ([row] bytes each, the leftmost pixel a
 * byte's high bit) *)
type font = { bits : string; row : int; height : int; glyphs : glyph array }

(* (Font.default's reading of the same bytes, where the image goes to the display) *)
let font () : font =
  let s = Font_default.data in
  let num (o : int) : int = int_of_string (String.trim (String.sub s o 12)) in
  let width = num 36 - num 12 and rows = num 48 - num 24 in
  let row = (width + 7) / 8 in
  let o = 60 + (row * rows) in
  let n = num o and height = num (o + 12) in
  let glyphs = Array.init (n + 1) (fun (k : int) ->
    let g = o + 36 + (6 * k) in
    let b (j : int) : int = Char.code s.[g + j] in
    { x = b 0 lor (b 1 lsl 8); top = b 2; bottom = b 3; left = (if b 4 > 127 then b 4 - 256 else b 4); advance = b 5 }) in
  { bits = String.sub s 60 (row * rows); row; height; glyphs }

(* (every character of this font moves the pen as much: a space's) *)
let cell (f : font) : int * int = (f.glyphs.(32).advance, f.height)

let glyph (p : t) (f : font) (x : int) (y : int) (c : Cells.rgb) (ch : string) : unit =
  (* (a character the font has not is its first one, as Font's) *)
  let k = Utf8.code ch in
  let k = if k < Array.length f.glyphs - 1 then k else 0 in
  let g = f.glyphs.(k) in
  let w = f.glyphs.(k + 1).x - g.x in
  for j = g.top to g.bottom - 1 do
    for i = 0 to w - 1 do
      let fx = g.x + i in
      if Char.code f.bits.[(j * f.row) + (fx / 8)] land (0x80 lsr (fx land 7)) <> 0 then set p (x + g.left + i) (y + j) c
    done
  done

let surface (p : t) (f : font) : Cells.surface =
  let w, h = cell f in
  { Cells.w; h; fill = fill p; glyph = glyph p f }

let ppm (p : t) : string = Printf.sprintf "P6\n%d %d\n255\n" p.w p.h ^ Bytes.to_string p.pixels
