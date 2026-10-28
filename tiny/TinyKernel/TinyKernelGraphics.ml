(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelGraphics.mli *)

(* OCaml builds this file too, on the host, where it is tested without
 * a machine (tests/TinyKernelGraphics_tests/Host.ml) *)

open TinyMemory

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
 * udivmod.tm: not when the pixel is there already) *)
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
 * (from the same point) are not 0. Clipped to the three images. A row
 * is one of TinyMemory's three loops where it can be: a copy, a colour
 * (a source of one pixel that repeats, read once), a colour through a
 * mask (a character); a pixel at a time otherwise. A row's address is
 * the first's and so many widths (d0 and dw, s0 and sw), not a call.
 * An image drawn on itself is read before it is written: its rows from
 * the last when it moves down, a row from its last pixel when it moves
 * right. *)
let draw (dst : image) (r : rect) (src : image) (mask : image option) px py =
  let dx = px - r.x0 and dy = py - r.y0 in
  let r = within (inter r dst.r) src dx dy in
  let r = match mask with Some m -> within r m dx dy | None -> r in
  let n = r.x1 - r.x0 in
  let backwards = src.at = dst.at && (dy < 0 || (dy = 0 && dx < 0)) in
  let colour = src.repl && width src = 1 && height src = 1 in
  let ink = if colour then peekb src.at else 0 in
  if n > 0 && r.y1 > r.y0 then begin
    let d0 = pixel dst r.x0 r.y0 and dw = width dst in
    let s0 = if src.repl then 0 else pixel src (r.x0 + dx) (r.y0 + dy)
    and sw = width src in
    for k = 0 to r.y1 - r.y0 - 1 do
      let k = if backwards then r.y1 - r.y0 - 1 - k else k in
      let y = r.y0 + k and d = d0 + (k * dw) in
      match mask with
      | None when colour -> row_fill d ink n
      | None when not src.repl && not (backwards && dy = 0) ->
          row_copy d (s0 + (k * sw)) n
      | Some m when colour && not m.repl ->
          row_mask d ink (pixel m (r.x0 + dx) (y + dy)) n
      | _ ->
          for j = 0 to n - 1 do
            let x = if backwards then r.x1 - 1 - j else r.x0 + j in
            if (match mask with
                | Some m -> peekb (pixel m (x + dx) (y + dy)) <> 0
                | None -> true)
            then pokeb (d + x - r.x0) (peekb (pixel src (x + dx) (y + dy)))
          done
    done
  end

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

(*****************************************************************************)
(* The font *)
(*****************************************************************************)

(* The machine's font: faces of 128 characters, a face's rows one after
 * the other, a row's left pixel the low bit of its first byte. The
 * first face is 8 by 16, a row a byte, and may be all the font has
 * (xv6's font1.bin, which mini-9pi's console has too). tiny.font
 * (fonts/README.md, made of Terminus Font) has three more after it:
 * bold 8 by 16, large 16 by 32 (a row two bytes), and large bold.
 * A face is made a mask: a byte a pixel (255 where it is set, so that
 * a character's row is two words of mask for draw.tm's glyphs), the
 * characters side by side in an image of 128 characters' width, so
 * that a character is a draw. *)
let mask bits w h at =
  let bytes = (w + 7) lsr 3 in
  for c = 0 to 127 do
    for row = 0 to h - 1 do
      for col = 0 to w - 1 do
        pokeb (at + (row * 128 * w) + (c * w) + col)
          (255 * ((peekb (bits + (((c * h) + row) * bytes) + (col lsr 3))
                   lsr (col land 7)) land 1))
      done
    done
  done;
  { r = rect 0 0 (128 * w) h; at = at; repl = false }

(* where the font's faces after the first are (0: it has none) *)
let faces = ref 0

(* [font_mask bits size at]: the font of size bytes at bits, its first
 * face made a mask at at (16 KB), the others' place kept for styled *)
let font_mask bits size at =
  faces := if size > 2048 then bits + 2048 else 0;
  mask bits 8 16 at

(* a text, its top left corner at (x, y): each character the ink src
 * through the font's mask (a byte beyond the font's 128 is a ?) *)
let text (dst : image) x y (src : image) (font : image) s =
  let n = String.length s in
  (* A text all inside dst, in a colour, at a whole word (what a program
   * draws nearly always): all its characters by one call of draw.tm's
   * glyphs, which works a word at a time. *)
  if n > 0 && not dst.repl && src.repl && width src = 1 && height src = 1
     && x >= dst.r.x0 && y >= dst.r.y0
     && x + (8 * n) <= dst.r.x1 && y + 16 <= dst.r.y1
     && (pixel dst x y) land 3 = 0 && (width dst) land 3 = 0
  then glyphs (pixel dst x y) (width dst) (peekb src.at) font.at s n
  else
    for i = 0 to n - 1 do
      let c = Char.code s.[i] in
      draw dst (rect (x + (8 * i)) y (x + (8 * i) + 8) (y + 16)) src (Some font)
        (8 * if c > 127 then 63 else c) 0
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
    if last > first then row_bytes s (off + first) (row + first) (last - first)
  end

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

(* src's characters, each pixel scale by scale, bold, slanted *)
let make (src : image) scale bold slant =
  let sw = width src / 128 in
  let cw = (sw * scale) + slant and ch = height src * scale in
  let w = 128 * cw in
  let at = alloc (w * ch) in
  row_fill at 0 (w * ch);
  for c = 0 to 127 do
    for row = 0 to ch - 1 do
      let shift = slant * (ch - 1 - row) / ch
      and line = src.at + (row / scale * width src) + (c * sw) in
      let set col = col >= 0 && col < sw && peekb (line + col) <> 0 in
      for col = 0 to (sw * scale) - 1 do
        let k = col / scale in
        if set k || (bold && set (k - 1) && not (set (k + 1))) then
          pokeb (at + (row * w) + (c * cw) + col + shift) 255
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
          mask (!faces + at) w (2 * w) (alloc (256 * w * w))
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
        row_fill (pixel dst x0 row) (Char.code s.[!i]) (x1 - x0)
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
  for i = 0 to n - 1 do
    let c = Char.code s.[i] in
    let x0 = x + (cw * i) in
    draw dst (rect x0 y (x0 + fw) (y + height f)) src (Some f)
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
      row_fill made.at (arg 6 land 255) (w * h);
      c.images <- (arg 0, made) :: c.images
  | 'f' -> release c (arg 0)
  | 'c' -> !cursor_hook (arg 0)
  | 'd' ->
      let mask = if arg 2 < 0 then None else Some (find c (arg 2)) in
      draw (find c (arg 0)) (rect (arg 3) (arg 4) (arg 5) (arg 6))
        (find c (arg 1)) mask (arg 7) (arg 8)
  | 'l' ->
      line (find c (arg 0)) (arg 2) (arg 3) (arg 4) (arg 5) (find c (arg 1))
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
 * them: where the next starts is not known. (old: a bad one raised at
 * once, the rest of the write not done: a page's picture with no room
 * left, its pixels' messages after it, and the texts after those) *)
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
        | 'a' -> 15 | 'f' | 'c' -> 3 | 'd' -> 19 | 'l' -> 13
        | 's' -> 11 + max 0 (arg 4) | 't' -> 13 + max 0 (arg 4)
        | 'p' -> 9 + max 0 (arg 3)
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
