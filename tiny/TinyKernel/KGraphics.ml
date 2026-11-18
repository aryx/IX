(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* testing:
 * OCaml builds this file too, on the host, where it is tested without
 * a machine (tests/KGraphics_tests/Host.ml)
 *)


(* a bad message, or no memory: a program's mistake, said to it *)
exception Graphics of string

(*****************************************************************************)
(* Images *)
(*****************************************************************************)

(* a rectangle of the plane: from (x0, y0), up to but not (x1, y1) *)
type rect = { x0 : int; y0 : int; x1 : int; y1 : int }

(* an image: its rectangle, where its bytes are (a row after the other,
 * a byte a pixel), and whether it repeats, covering the plane *)
type image = { r : rect; at : int; repl : bool }

let rect x0 y0 x1 y1 = { x0 = x0; y0 = y0; x1 = x1; y1 = y1 }
let inter (a : rect) (b : rect) =
  rect (max a.x0 b.x0) (max a.y0 b.y0) (min a.x1 b.x1) (min a.y1 b.y1)
let width (i : image) = i.r.x1 - i.r.x0
let height (i : image) = i.r.y1 - i.r.y0

(* where the pixel at (x, y) is: a repeating image's is first taken
 * back into its rectangle (tiny-machine divides by a loop, in
 * udivmod.s: not when the pixel is there already) *)
let back repl v n = if v >= 0 && v < n || not repl then v else ((v mod n) + n) mod n
let pixel (i : image) x y =
  i.at + (back i.repl (y - i.r.y0) (height i) * width i)
  + back i.repl (x - i.r.x0) (width i)

(*****************************************************************************)
(* draw *)
(*****************************************************************************)

(* r without what a source has no pixel for, the source's (x + dx,
 * y + dy) being drawn at (x, y); one that repeats has them all *)
let within (r : rect) (s : image) dx dy =
  if s.repl then r
  else inter r (rect (s.r.x0 - dx) (s.r.y0 - dy) (s.r.x1 - dx) (s.r.y1 - dy))

(* dst's rectangle r: src's pixels from (px, py) on, where the mask's
 * (from the same point) are not 0; with a colour's table of mixes
 * (mix, below; 0: none), a colour mixed by the mask's level, a grey
 * font's edges (a source of more than a colour takes the mask as set or
 * not). Clipped to the three images. A row
 * is one of KRaw's three loops where it can be: a copy, a colour
 * (a source of one pixel that repeats, read once), a colour through a
 * mask (a character); a pixel at a time otherwise. A row's address is
 * the first's and so many widths (d0 and dw, s0 and sw), not a call.
 * An image drawn on itself is read before it is written: its rows from
 * the last when it moves down, a row from its last pixel when it moves
 * right. *)
let draw_mixed mix (dst : image) (r : rect) (src : image) (mask : image option)
    px py =
  let dx = px - r.x0 and dy = py - r.y0 in
  let r = within (inter r dst.r) src dx dy in
  let r = match mask with Some m -> within r m dx dy | None -> r in
  let n = r.x1 - r.x0 in
  let backwards = src.at = dst.at && (dy < 0 || (dy = 0 && dx < 0)) in
  let colour = src.repl && width src = 1 && height src = 1 in
  let ink = if colour then KRaw.peekb src.at else 0 in
  if n > 0 && r.y1 > r.y0 then begin
    let d0 = pixel dst r.x0 r.y0 and dw = width dst in
    let s0 = if src.repl then 0 else pixel src (r.x0 + dx) (r.y0 + dy)
    and sw = width src in
    for k = 0 to r.y1 - r.y0 - 1 do
      let k = if backwards then r.y1 - r.y0 - 1 - k else k in
      let y = r.y0 + k and d = d0 + (k * dw) in
      match mask with
      | None when colour -> KRaw.row_fill d ink n
      | None when not src.repl && not (backwards && dy = 0) ->
          KRaw.row_copy d (s0 + (k * sw)) n
      | Some m when colour && not m.repl && mix <> 0 ->
          KRaw.row_mix d mix (pixel m (r.x0 + dx) (y + dy)) n
      | Some m when colour && not m.repl ->
          KRaw.row_mask d ink (pixel m (r.x0 + dx) (y + dy)) n
      | _ ->
          for j = 0 to n - 1 do
            let x = if backwards then r.x1 - 1 - j else r.x0 + j in
            if (match mask with
                | Some m -> KRaw.peekb (pixel m (x + dx) (y + dy)) <> 0
                | None -> true)
            then
              KRaw.pokeb (d + x - r.x0)
                (KRaw.peekb (pixel src (x + dx) (y + dy)))
          done
    done
  end

let draw dst r src mask px py = draw_mixed 0 dst r src mask px py

(* a line from (xa, ya) to (xb, yb), both drawn, a pixel thick:
 * Bresenham's, each of its points a draw (clipped there) *)
let line (dst : image) xa ya xb yb (src : image) =
  (* (a level or an upright line is a rectangle, one draw: a link's
   * underline was a draw a pixel) *)
  if ya = yb || xa = xb then
    draw dst (rect (min xa xb) (min ya yb) (max xa xb + 1) (max ya yb + 1))
      src None (min xa xb) (min ya yb)
  else
  let dx = abs (xb - xa) and dy = abs (yb - ya) in
  let sx = if xa < xb then 1 else -1 and sy = if ya < yb then 1 else -1 in
  let rec from x y err =
    draw dst (rect x y (x + 1) (y + 1)) src None x y;
    if x <> xb || y <> yb then begin
      let across = 2 * err + dy > 0 and down = 2 * err < dx in
      from (if across then x + sx else x) (if down then y + sy else y)
        (err - (if across then dy else 0) + (if down then dx else 0))
    end
  in
  from xa ya (dx - dy)

(* The largest r with r * r <= n, by Newton's method from a guess r
 * that is at least as large. Each step's r goes down until it stops. *)
let rec root n r =
  let s = (r + (n / r)) / 2 in
  if s >= r then r else root n s

(* An ellipse's half width at row y from its centre, for its half axes
 * a and b, or -1 past its top and bottom. A pixel is in when its centre
 * is in the ellipse of half axes a + 1/2 and b + 1/2, which makes a
 * circle of radius 3 seven pixels wide on its three middle rows, as
 * m-IX's Memshape.ml does with floats. With the half axes doubled, the
 * numbers are integers: x <= A sqrt (B^2 - 4 y^2) / 2B, for A = 2a + 1
 * and B = 2b + 1. Each product stays under 2^30, tiny-ml's largest
 * integer, while a and b are at most 16383. *)
let half_width a b y =
  if y < -b || y > b then -1
  else
    let aa = (2 * a) + 1 and bb = (2 * b) + 1 in
    let m = (bb * bb) - (4 * y * y) in
    aa * root m bb / (2 * bb)

(* row y's pixels from x0 to x1, both drawn *)
let span (dst : image) y x0 x1 (src : image) =
  draw dst (rect x0 y (x1 + 1) (y + 1)) src None x0 y

(* [ellipse_rows dst cy a b row] calls [row y w w_out] for each row of
 * the ellipse that is inside dst, where w is the row's half width and
 * w_out is the half width of the next row away from the centre. The
 * rows outside dst are skipped before the loop, so a huge ellipse
 * mostly off the screen costs only its visible rows. *)
let ellipse_rows (dst : image) cy a b row =
  if a < 0 || b < 0 || a > 16383 || b > 16383 then
    raise (Graphics "an ellipse of no size, or too large");
  for y = max (-b) (dst.r.y0 - cy) to min b (dst.r.y1 - 1 - cy) do
    row (cy + y) (half_width a b y)
      (half_width a b (if y < 0 then y - 1 else y + 1))
  done

(* A filled ellipse is one draw for each row. *)
let fill_ellipse (dst : image) cx cy a b (src : image) =
  ellipse_rows dst cy a b (fun y w _ -> span dst y (cx - w) (cx + w) src)

(* An outline is the part of each row that the next row away from the
 * centre does not cover, on each side: one pixel on the rows where
 * the curve is steep, many near the top and the bottom where it is
 * flat, so that the outline has no gap. The top and the bottom rows
 * are drawn whole. *)
let ellipse (dst : image) cx cy a b (src : image) =
  ellipse_rows dst cy a b (fun y w w_out ->
    let inner = min w (w_out + 1) in
    if inner = 0 then span dst y (cx - w) (cx + w) src
    else begin
      span dst y (cx - w) (cx - inner) src;
      span dst y (cx + inner) (cx + w) src
    end)

(* The first pixel of row y whose centre is right of the edge from
 * (xa, ya) down to (xb, yb), or on it, for ya <= y < yb. A point's
 * numbers are a pixel's top left corner, so the row's centres are at
 * y + 1/2 and the edge is there at xa + (xb - xa) (2 (y - ya) + 1) /
 * 2 (yb - ya); the pixel is that less a half, rounded up. *)
let crossing (xa, ya) (xb, yb) y =
  let n = ((xb - xa) * ((2 * (y - ya)) + 1)) - (yb - ya)
  and d = 2 * (yb - ya) in
  xa + (if n >= 0 then (n + d - 1) / d else - (- n / d))

let rec insert (x : int) l =
  match l with
  | h :: t when h < x -> h :: insert x t
  | _ -> x :: l

(* A filled polygon is, on each row, the pixels between the first and
 * the second of its edges that cross the row, between the third and
 * the fourth, and so on (the even-odd rule: a place is inside when a
 * ray from it crosses the edges an odd number of times). A pixel is in
 * when its centre is inside, or on a left edge; so the polygon of a
 * rectangle's four corners is that rectangle, and two polygons that
 * share an edge neither overlap nor leave a gap. An edge counts for
 * the rows from its upper end to just above its lower end, so a
 * corner between two edges is crossed once, and a flat edge never.
 * A side of the polygon's box is at most 16383, which keeps
 * [crossing]'s product under 2^30, tiny-ml's largest integer. *)
let fill_polygon (dst : image) (points : (int * int) list) (src : image) =
  match points with
  | [] -> ()
  | (x, y) :: _ ->
      let x0 = List.fold_left (fun m (px, _) -> min m px) x points
      and x1 = List.fold_left (fun m (px, _) -> max m px) x points
      and y0 = List.fold_left (fun m (_, py) -> min m py) y points
      and y1 = List.fold_left (fun m (_, py) -> max m py) y points in
      if x1 - x0 > 16383 || y1 - y0 > 16383 then
        raise (Graphics "a polygon too large");
      (* the last point's edge goes back to the first *)
      let rec edges l =
        match l with
        | a :: b :: rest -> (a, b) :: edges (b :: rest)
        | [ last ] -> [ last, (x, y) ]
        | [] -> []
      in
      let edges = edges points in
      let rec fill row l =
        match l with
        | a :: b :: rest -> if b > a then span dst row a (b - 1) src; fill row rest
        | _ -> ()
      in
      for row = max y0 dst.r.y0 to min y1 dst.r.y1 - 1 do
        fill row
          (List.fold_left (fun acc ((xa, ya), (xb, yb)) ->
             if ya <= row && row < yb then
               insert (crossing (xa, ya) (xb, yb) row) acc
             else if yb <= row && row < ya then
               insert (crossing (xb, yb) (xa, ya) row) acc
             else acc) [] edges)
      done

(*****************************************************************************)
(* The images' memory *)
(*****************************************************************************)

(* Outside the collected heap (a megabyte of pixels would be copied at
 * each collection): the free blocks, an address and a size each, by
 * address. The first that fits is taken from; a block freed joins the
 * ones it touches. *)
let blocks = ref []
let arena at n = blocks := [ at, n ]

(* (a block is whole words: an image then starts at a multiple of 4,
 * and a row of it is copied a word at a time to one that does too) *)
let words n = (n + 3) land lnot 3

let alloc n =
  let n = words n in
  let rec take = function
    | [] -> raise (Graphics "no memory for an image")
    | (a, size) :: rest when size >= n ->
        a, if size = n then rest else (a + n, size - n) :: rest
    | b :: rest -> let a, rest = take rest in a, b :: rest
  in
  let a, rest = take !blocks in
  blocks := rest;
  a

let free at n =
  let n = words n in
  let rec put = function
    | (a, size) :: rest when a < at -> (a, size) :: put rest
    | rest -> (at, n) :: rest
  in
  let rec join = function
    | (a, size) :: (b, more) :: rest when a + size = b ->
        join ((a, size + more) :: rest)
    | b :: rest -> b :: join rest
    | [] -> []
  in
  blocks := join (put !blocks)

(*****************************************************************************)
(* Mixes *)
(*****************************************************************************)

(* A pixel's byte is a colour of Plan 9's table (rgbv: TinyMachineDevices
 * says how it is made): two bits of red, two of how bright (v), four of
 * green and blue, turned by the first two so that a row of 16 is a
 * ramp. Its red, green and blue (TinyMachineDevices's formula again:
 * the machine is the host's code, which the kernel does not link): *)
let rgb i =
  let r = i lsr 6 and v = (i lsr 4) land 3 in
  let j = (i - v + r) land 15 in
  let g = j lsr 2 and b = j land 3 in
  let den = max r (max g b) in
  if den = 0 then (17 * v, 17 * v, 17 * v)
  else
    let num = 17 * ((4 * den) + v) in
    (r * num / den, g * num / den, b * num / den)

(* A colour's mixes, for a mask of levels (a grey font's): 1,024 bytes,
 * four rows of 256, a row a level of the mask's (its byte's two high
 * bits: 0, 85, 170, 255 are 0 to 3), its byte k what a pixel of colour
 * k becomes: as it was, a third of the ink, two thirds, the ink; each
 * the colour of the table nearest to the mix. Made by KRaw's
 * mix_table when the colour is first drawn with, from [palette] (each
 * colour's red, green and blue, 768 bytes, made at the first), and kept
 * for good: an address in [mixes] (0: not made). It is made in KRaw,
 * not here: tiny-ml's array reads made it 3.5 million instructions a
 * colour, half a second, and tiny-windows' first menu was drawn so late
 * that the click on it was taken for its last item, exit *)
let mixes = Array.make 256 0
let palette = ref 0

let mix ink =
  if !palette = 0 then begin
    palette := alloc 768;
    for i = 0 to 255 do
      let r, g, b = rgb i in
      KRaw.pokeb (!palette + (3 * i)) r;
      KRaw.pokeb (!palette + (3 * i) + 1) g;
      KRaw.pokeb (!palette + (3 * i) + 2) b
    done
  end;
  if mixes.(ink) = 0 then begin
    let at = alloc 1024 in
    KRaw.mix_table at ink !palette;
    mixes.(ink) <- at
  end;
  mixes.(ink)

(*****************************************************************************)
(* The font *)
(*****************************************************************************)

(* The machine's font: faces of 128 characters, a face's rows one after
 * the other, a row's left pixel the low bit of its first byte. The
 * first face is 8 by 16, a row a byte, and may be all the font has
 * (xv6's font1.bin, which mini-9pi's console has too). tiny.font
 * (fonts/README.md, made of Ubuntu Mono) has three more after it:
 * bold 8 by 16, large 16 by 32 (a row two bytes), and large bold.
 * grey.font has the same faces, a pixel two bits (the depth, 2), its
 * level: 0 none, 3 the ink, 1 and 2 a third and two of it, the
 * letters' edges (a row then w / 4 bytes, each face twice as large).
 * A face is made a mask: a byte a pixel (255 where it is set, so that
 * a character's row is two words of mask for kdraw.s's glyphs; 85 and
 * 170 the two greys), the characters side by side in an image of 128
 * characters' width, so that a character is a draw. *)
let mask bits depth w h at =
  let bytes = ((w * depth) + 7) lsr 3 and top = (1 lsl depth) - 1 in
  for c = 0 to 127 do
    for row = 0 to h - 1 do
      for col = 0 to w - 1 do
        let b = col * depth in
        KRaw.pokeb (at + (row * 128 * w) + (c * w) + col)
          (255 / top
           * ((KRaw.peekb (bits + (((c * h) + row) * bytes) + (b lsr 3))
               lsr (b land 7)) land top))
      done
    done
  done;
  { r = rect 0 0 (128 * w) h; at = at; repl = false }

(* where the font's faces after the first are (0: it has none), and its
 * depth, a pixel's bits: 1, or 2 for grey.font *)
let faces = ref 0
let depth = ref 1

(* [font_mask bits size at]: the font of size bytes at bits, its first
 * face made a mask at at (16 KB), the others' place kept for styled; a
 * font of 40,960 bytes has levels (grey.font, twice tiny.font's) *)
let font_mask bits size at =
  depth := if size = 40960 then 2 else 1;
  faces := if size > 2048 then bits + (2048 * !depth) else 0;
  mask bits !depth 8 16 at

(* the mixes of src when it is a colour and the font has levels: what a
 * text is drawn with (0: none, its mask set or not) *)
let mixing (src : image) =
  if !depth = 2 && src.repl && width src = 1 && height src = 1
  then mix (KRaw.peekb src.at) else 0

(* a text, its top left corner at (x, y): each character the ink src
 * through the font's mask (a byte beyond the font's 128 is a ?) *)
let text (dst : image) x y (src : image) (font : image) s =
  let n = String.length s in
  let mix = mixing src in
  (* A text all inside dst, in a colour, at a whole word (what a program
   * draws nearly always): all its characters by one call of kdraw.s's
   * glyphs, which works a word at a time; with levels its glyphs_mixed,
   * a byte at a time where a row is not blank. *)
  if n > 0 && not dst.repl && src.repl && width src = 1 && height src = 1
     && x >= dst.r.x0 && y >= dst.r.y0
     && x + (8 * n) <= dst.r.x1 && y + 16 <= dst.r.y1
     && (pixel dst x y) land 3 = 0 && (width dst) land 3 = 0
  then
    if mix <> 0 then
      KRaw.glyphs_mixed (pixel dst x y) (width dst) mix font.at s n
    else KRaw.glyphs (pixel dst x y) (width dst) (KRaw.peekb src.at) font.at s n
  else
    for i = 0 to n - 1 do
      let c = Char.code s.[i] in
      draw_mixed mix dst (rect (x + (8 * i)) y (x + (8 * i) + 8) (y + 16)) src
        (Some font) (8 * if c > 127 then 63 else c) 0
    done

(* a row of pixels given as they are, its left end at (x, y): the n
 * bytes of s from off, those that fall in dst. What a picture that
 * comes from elsewhere is drawn by, a row a message (Plan 9's load) *)
let pixels (dst : image) x y s off n =
  if y >= dst.r.y0 && y < dst.r.y1 then begin
    let row = dst.at + ((y - dst.r.y0) * width dst) - dst.r.x0 + x in
    let first = max 0 (dst.r.x0 - x) and last = min n (dst.r.x1 - x) in
    (* old: for k = first to last - 1 do
     *   pokeb (row + k) (Char.code s.[off + k]) done:
     * two calls of C a pixel, 300 instructions; a picture's row of 320
     * was 12 ms of the machine's time *)
    if last > first then
      KRaw.row_bytes s (off + first) (row + first) (last - first)
  end

(*****************************************************************************)
(* Styled text *)
(*****************************************************************************)

(* The faces of a word processor's styles, a mask each, made when first
 * asked for: bold, large, and those two, the font's own when it has
 * them (tiny.font), else made from its first face (font1.bin): bold,
 * each stroke one pixel wider, but for a gap of one pixel, which stays
 * (drawn twice, a pixel apart, an m was a block); large, each pixel 2
 * by 2. Italic is made from the upright face, real or made, its rows
 * slanted, the top ones 3 pixels right, 6 when large (its cells 11
 * wide, 22, so that a character's slant is in its own cell). Made once,
 * at the first text that needs one: a large one is some 65,000 pixels. *)
let derived = Array.make 8 None

(* src's characters, each pixel scale by scale, bold, slanted; a
 * pixel's level kept (a grey font's) *)
let make (src : image) scale bold slant =
  let sw = width src / 128 in
  let cw = (sw * scale) + slant and ch = height src * scale in
  let w = 128 * cw in
  let at = alloc (w * ch) in
  KRaw.row_fill at 0 (w * ch);
  for c = 0 to 127 do
    for row = 0 to ch - 1 do
      let shift = slant * (ch - 1 - row) / ch
      and line = src.at + (row / scale * width src) + (c * sw) in
      let level col =
        if col >= 0 && col < sw then KRaw.peekb (line + col) else 0 in
      let set col = level col <> 0 in
      for col = 0 to (sw * scale) - 1 do
        let k = col / scale in
        if set k then
          KRaw.pokeb (at + (row * w) + (c * cw) + col + shift) (level k)
        else if bold && set (k - 1) && not (set (k + 1)) then
          KRaw.pokeb (at + (row * w) + (c * cw) + col + shift) (level (k - 1))
      done
    done
  done;
  { r = rect 0 0 w ch; at = at; repl = false }

(* kind: italic 1, large 2, bold 4 *)
let rec derive (font : image) kind =
  match derived.(kind) with
  | Some f -> f
  | None ->
      let large = kind land 2 <> 0 in
      let f =
        if kind land 1 <> 0 then
          make (if kind = 1 then font else derive font (kind land 6)) 1 false
            (if large then 6 else 3)
        else if !faces <> 0 then
          let w = if large then 16 else 8
          and at = if kind = 4 then 0 else if kind = 2 then 2048 else 10240 in
          mask (!faces + (at * !depth)) !depth w (2 * w) (alloc (256 * w * w))
        else make font (if large then 2 else 1) (kind land 4 <> 0) 0
      in
      derived.(kind) <- Some f;
      f

(* a row of fat pixels, each byte of s a colour, a square of 4 by 4: a
 * run of one colour filled at once, row by row, what is outside dst
 * left (a paint's picture, a row a message) *)
let fat (dst : image) x y s =
  let n = String.length s and i = ref 0 in
  while !i < n do
    let j = ref (!i + 1) in
    while !j < n && s.[!j] = s.[!i] do incr j done;
    let x0 = max dst.r.x0 (x + (4 * !i)) and x1 = min dst.r.x1 (x + (4 * !j)) in
    if x1 > x0 then
      for row = max dst.r.y0 y to min dst.r.y1 (y + 4) - 1 do
        KRaw.row_fill (pixel dst x0 row) (Char.code s.[!i]) (x1 - x0)
      done;
    i := !j
  done

(* a text in a style, its top left corner at (x, y): bold 1, italic 2,
 * underlined 4, large 8 (16 by 32 a character); or 16, fat pixels *)
let styled (dst : image) x y (src : image) (font : image) style s =
  if style land 16 <> 0 then fat dst x y s
  else
  let kind =
    (if style land 2 <> 0 then 1 else 0)
    lor (if style land 8 <> 0 then 2 else 0)
    lor (if style land 1 <> 0 then 4 else 0)
  in
  let f = if kind = 0 then font else derive font kind in
  let scale = if style land 8 <> 0 then 2 else 1 in
  let cw = 8 * scale and fw = width f / 128 and n = String.length s in
  let mix = mixing src in
  (* bold, underlined or neither: 8 by 16 cells, the plain text's, so
   * text and its word at a time: a draw a character, some 13,000
   * instructions, made a screen of tiny-emacs in bold 30 million *)
  if kind land 3 = 0 then text dst x y src f s
  else
  for i = 0 to n - 1 do
    let c = Char.code s.[i] in
    let x0 = x + (cw * i) in
    draw_mixed mix dst (rect x0 y (x0 + fw) (y + height f)) src (Some f)
      (fw * if c > 127 then 63 else c) 0
  done;
  if style land 4 <> 0 then
    draw dst
      (rect x (y + height f - (2 * scale)) (x + (cw * n)) (y + height f - scale))
      src None 0 0

(*****************************************************************************)
(* The messages *)
(*****************************************************************************)

(* a connection: a program's images by its numbers for them, 0 the one
 * it was given; the font its texts are in *)
type conn = { mutable images : (int * image) list; font : image }

let connect (screen : image) (font : image) = { images = [ 0, screen ]; font = font }
let find (c : conn) id =
  try List.assoc id c.images with Not_found -> raise (Graphics "no such image")

let release (c : conn) id =
  let i = find c id in
  if id = 0 then raise (Graphics "image 0 is not freed");
  free i.at (width i * height i);
  c.images <- List.filter (fun (k, _) -> k <> id) c.images

(* the connection's end: what the program left *)
let disconnect (c : conn) =
  List.iter (fun (id, _) -> if id <> 0 then release c id) c.images

(* What the 'c' message (the mouse's look) does: set by the kernel, which
 * writes it to the machine's mouse word; nothing on the host. *)
let cursor_hook = ref (fun (_ : int) -> ())

(* the message at s.[i], its numbers by arg: whole, its size
 * checked by messages *)
let message (c : conn) s i arg =
  let len k =
    if arg k < 0 then raise (Graphics "a negative length") else arg k in
  match s.[i] with
  | 'a' ->
      let w = arg 3 - arg 1 and h = arg 4 - arg 2 in
      if w <= 0 || h <= 0 || w > 2048 || h > 2048 then
        raise (Graphics "an image of no size, or too large");
      if List.exists (fun (k, _) -> k = arg 0) c.images then release c (arg 0);
      let made =
        { r = rect (arg 1) (arg 2) (arg 3) (arg 4);
          at = alloc (w * h); repl = arg 5 <> 0 }
      in
      KRaw.row_fill made.at (arg 6 land 255) (w * h);
      c.images <- (arg 0, made) :: c.images
  | 'f' -> release c (arg 0)
  | 'c' -> !cursor_hook (arg 0)
  | 'd' ->
      let mask = if arg 2 < 0 then None else Some (find c (arg 2)) in
      draw (find c (arg 0)) (rect (arg 3) (arg 4) (arg 5) (arg 6))
        (find c (arg 1)) mask (arg 7) (arg 8)
  | 'l' ->
      line (find c (arg 0)) (arg 2) (arg 3) (arg 4) (arg 5) (find c (arg 1))
  | 'e' ->
      ellipse (find c (arg 0)) (arg 2) (arg 3) (arg 4) (arg 5) (find c (arg 1))
  | 'E' ->
      fill_ellipse (find c (arg 0)) (arg 2) (arg 3) (arg 4) (arg 5)
        (find c (arg 1))
  | 'P' ->
      let rec points k =
        if k >= len 2 then []
        else (arg (3 + (2 * k)), arg (4 + (2 * k))) :: points (k + 1) in
      fill_polygon (find c (arg 0)) (points 0) (find c (arg 1))
  | 's' ->
      text (find c (arg 0)) (arg 2) (arg 3) (find c (arg 1)) c.font
        (String.sub s (i + 11) (len 4))
  | 't' ->
      styled (find c (arg 0)) (arg 2) (arg 3) (find c (arg 1)) c.font (arg 5)
        (String.sub s (i + 13) (len 4))
  | _ (* 'p' *) -> pixels (find c (arg 0)) (arg 1) (arg 2) s (i + 9) (len 3)

(* a write's bytes: whole messages (the header says which), each done
 * in turn; a bad one skipped, the ones after it done, then Graphics
 * raised with the first's why. A message cut short, or unknown, ends
 * them: where the next starts is not known. A bad one does not stop the
 * write, else a page's picture with no room left would lose the texts
 * after it *)
let messages (c : conn) s =
  let n = String.length s in
  let first = ref "" in
  let rec next i =
    if i < n then begin
      let arg k =
        let at = i + 1 + (2 * k) in
        if at + 2 > n then raise (Graphics "a message cut short");
        let v = Char.code s.[at] + (256 * Char.code s.[at + 1]) in
        if v >= 32768 then v - 65536 else v
      in
      let size =
        match s.[i] with
        | 'a' -> 15 | 'f' | 'c' -> 3 | 'd' -> 19 | 'l' | 'e' | 'E' -> 13
        | 's' -> 11 + max 0 (arg 4) | 't' -> 13 + max 0 (arg 4)
        | 'p' -> 9 + max 0 (arg 3)
        | 'P' -> 7 + (4 * max 0 (arg 2))
        | _ -> raise (Graphics "an unknown message")
      in
      if i + size > n then raise (Graphics "a message cut short");
      (try message c s i arg
       with Graphics why -> if !first = "" then first := why);
      next (i + size)
    end
  in
  next 0;
  if !first <> "" then raise (Graphics !first)
