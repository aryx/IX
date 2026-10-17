(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelGraphics.mli *)

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
let inter (a : rect) (b : rect) = rect (max a.x0 b.x0) (max a.y0 b.y0) (min a.x1 b.x1) (min a.y1 b.y1)
let width (i : image) = i.r.x1 - i.r.x0
let height (i : image) = i.r.y1 - i.r.y0

(* where the pixel at (x, y) is: a repeating image's is first taken
 * back into its rectangle (tiny-machine divides by a loop, in
 * udivmod.tm: not when the pixel is there already) *)
let back repl v n = if v >= 0 && v < n || not repl then v else ((v mod n) + n) mod n
let pixel (i : image) x y = i.at + (back i.repl (y - i.r.y0) (height i) * width i) + back i.repl (x - i.r.x0) (width i)

(*****************************************************************************)
(* draw *)
(*****************************************************************************)

(* r without what a source has no pixel for, the source's (x + dx,
 * y + dy) being drawn at (x, y); one that repeats has them all *)
let within (r : rect) (s : image) dx dy =
  if s.repl then r else inter r (rect (s.r.x0 - dx) (s.r.y0 - dy) (s.r.x1 - dx) (s.r.y1 - dy))

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
    let s0 = if src.repl then 0 else pixel src (r.x0 + dx) (r.y0 + dy) and sw = width src in
    for k = 0 to r.y1 - r.y0 - 1 do
      let k = if backwards then r.y1 - r.y0 - 1 - k else k in
      let y = r.y0 + k and d = d0 + (k * dw) in
      match mask with
      | None when colour -> row_fill d ink n
      | None when not src.repl && not (backwards && dy = 0) -> row_copy d (s0 + (k * sw)) n
      | Some m when colour && not m.repl -> row_mask d ink (pixel m (r.x0 + dx) (y + dy)) n
      | _ ->
          for j = 0 to n - 1 do
            let x = if backwards then r.x1 - 1 - j else r.x0 + j in
            if (match mask with Some m -> peekb (pixel m (x + dx) (y + dy)) <> 0 | None -> true)
            then pokeb (d + x - r.x0) (peekb (pixel src (x + dx) (y + dy)))
          done
    done
  end

(* a line from (xa, ya) to (xb, yb), both drawn, a pixel thick:
 * Bresenham's, each of its points a draw (clipped there) *)
let line (dst : image) xa ya xb yb (src : image) =
  (* (a level or an upright line is a rectangle, one draw: a link's
   * underline was a draw a pixel) *)
  if ya = yb || xa = xb then draw dst (rect (min xa xb) (min ya yb) (max xa xb + 1) (max ya yb + 1)) src None (min xa xb) (min ya yb)
  else
  let dx = abs (xb - xa) and dy = abs (yb - ya) in
  let sx = if xa < xb then 1 else -1 and sy = if ya < yb then 1 else -1 in
  let rec from x y err =
    draw dst (rect x y (x + 1) (y + 1)) src None x y;
    if x <> xb || y <> yb then begin
      let across = 2 * err + dy > 0 and down = 2 * err < dx in
      from (if across then x + sx else x) (if down then y + sy else y) (err - (if across then dy else 0) + (if down then dx else 0))
    end
  in
  from xa ya (dx - dy)

(*****************************************************************************)
(* The font *)
(*****************************************************************************)

(* The machine's font: 128 characters of 8 by 16, a row a byte, its
 * left pixel the low bit (xv6's font1.bin, which mini-9pi's console
 * has too). Made a mask once: a byte a pixel (255 where it is set, so
 * that a character's row is two words of mask for draw.tm's glyphs), the
 * characters side by side in an image of 1024 by 16, so that a
 * character is a draw. *)
let font_mask bits at =
  for c = 0 to 127 do
    for row = 0 to 15 do
      for col = 0 to 7 do pokeb (at + (row * 1024) + (c * 8) + col) (255 * ((peekb (bits + (c * 16) + row) lsr col) land 1)) done
    done
  done;
  { r = rect 0 0 1024 16; at = at; repl = false }

(* a text, its top left corner at (x, y): each character the ink src
 * through the font's mask (a byte beyond the font's 128 is a ?) *)
let text (dst : image) x y (src : image) (font : image) s =
  let n = String.length s in
  (* A text all inside dst, in a colour, at a whole word (what a program
   * draws nearly always): all its characters by one call of draw.tm's
   * glyphs, which works a word at a time. *)
  if n > 0 && not dst.repl && src.repl && width src = 1 && height src = 1
     && x >= dst.r.x0 && y >= dst.r.y0 && x + (8 * n) <= dst.r.x1 && y + 16 <= dst.r.y1
     && (pixel dst x y) land 3 = 0 && (width dst) land 3 = 0
  then glyphs (pixel dst x y) (width dst) (peekb src.at) font.at s n
  else
    for i = 0 to n - 1 do
      let c = Char.code s.[i] in
      draw dst (rect (x + (8 * i)) y (x + (8 * i) + 8) (y + 16)) src (Some font) (8 * if c > 127 then 63 else c) 0
    done

(* a row of pixels given as they are, its left end at (x, y): the n
 * bytes of s from off, those that fall in dst. What a picture that
 * comes from elsewhere is drawn by, a row a message (Plan 9's load) *)
let pixels (dst : image) x y s off n =
  if y >= dst.r.y0 && y < dst.r.y1 then begin
    let row = dst.at + ((y - dst.r.y0) * width dst) - dst.r.x0 + x in
    let first = max 0 (dst.r.x0 - x) and last = min n (dst.r.x1 - x) in
    (* old: for k = first to last - 1 do pokeb (row + k) (Char.code s.[off + k]) done:
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
    | (a, size) :: rest when size >= n -> a, if size = n then rest else (a + n, size - n) :: rest
    | b :: rest -> let a, rest = take rest in a, b :: rest
  in
  let a, rest = take !blocks in
  blocks := rest;
  a

let free at n =
  let n = words n in
  let rec put = function (a, size) :: rest when a < at -> (a, size) :: put rest | rest -> (at, n) :: rest in
  let rec join = function
    | (a, size) :: (b, more) :: rest when a + size = b -> join ((a, size + more) :: rest)
    | b :: rest -> b :: join rest
    | [] -> []
  in
  blocks := join (put !blocks)

(*****************************************************************************)
(* Styled text *)
(*****************************************************************************)

(* The fonts made from the machine's when first asked for (a word
 * processor's italic and large text): italic, its rows slanted, the
 * top ones 3 pixels right (its cells 11 wide, so that a character's
 * slant is in its own cell); large, each pixel 2 by 2; large italic.
 * Made once, at the first text that needs one: the large ones are some
 * 65,000 pixels looked at. *)
let derived = Array.make 4 None

let derive (font : image) kind =
  match derived.(kind) with
  | Some f -> f
  | None ->
      let scale = if kind land 2 <> 0 then 2 else 1 in
      let slant = if kind land 1 <> 0 then 3 * scale else 0 in
      let cw = (8 * scale) + slant and ch = 16 * scale in
      let w = 128 * cw in
      let at = alloc (w * ch) in
      row_fill at 0 (w * ch);
      for c = 0 to 127 do
        for row = 0 to ch - 1 do
          let shift = slant * (ch - 1 - row) / ch in
          for col = 0 to (8 * scale) - 1 do
            if peekb (font.at + (row / scale * 1024) + (c * 8) + (col / scale)) <> 0 then
              pokeb (at + (row * w) + (c * cw) + col + shift) 255
          done
        done
      done;
      let f = { r = rect 0 0 w ch; at = at; repl = false } in
      derived.(kind) <- Some f;
      f

(* a text in a style, its top left corner at (x, y): bold 1 (drawn
 * twice, a pixel apart, two when large), italic 2, underlined 4, large
 * 8 (16 by 32 a character) *)
let styled (dst : image) x y (src : image) (font : image) style s =
  let kind = (if style land 2 <> 0 then 1 else 0) lor (if style land 8 <> 0 then 2 else 0) in
  let f = if kind = 0 then font else derive font kind in
  let scale = if style land 8 <> 0 then 2 else 1 in
  let cw = 8 * scale and fw = width f / 128 and n = String.length s in
  for t = 0 to (if style land 1 <> 0 then 1 else 0) do
    for i = 0 to n - 1 do
      let c = Char.code s.[i] in
      let x0 = x + (cw * i) + (t * scale) in
      draw dst (rect x0 y (x0 + fw) (y + height f)) src (Some f) (fw * if c > 127 then 63 else c) 0
    done
  done;
  if style land 4 <> 0 then draw dst (rect x (y + height f - (2 * scale)) (x + (cw * n)) (y + height f - scale)) src None 0 0

(*****************************************************************************)
(* The messages *)
(*****************************************************************************)

(* a connection: a program's images by its numbers for them, 0 the one
 * it was given; the font its texts are in *)
type conn = { mutable images : (int * image) list; font : image }

let connect (screen : image) (font : image) = { images = [ 0, screen ]; font = font }
let find (c : conn) id = try List.assoc id c.images with Not_found -> raise (Graphics "no such image")

let release (c : conn) id =
  let i = find c id in
  if id = 0 then raise (Graphics "image 0 is not freed");
  free i.at (width i * height i);
  c.images <- List.filter (fun (k, _) -> k <> id) c.images

(* the connection's end: what the program left *)
let disconnect (c : conn) = List.iter (fun (id, _) -> if id <> 0 then release c id) c.images

(* What the 'c' message (the mouse's look) does: set by the kernel, which
 * writes it to the machine's mouse word; nothing on the host. *)
let cursor_hook = ref (fun (_ : int) -> ())

(* a write's bytes: whole messages (the header says which), each done
 * in turn; a bad one raises Graphics, the ones before it done *)
let messages (c : conn) s =
  let n = String.length s in
  let rec next i =
    if i < n then begin
      let arg k =
        let at = i + 1 + (2 * k) in
        if at + 2 > n then raise (Graphics "a message cut short");
        let v = Char.code s.[at] + (256 * Char.code s.[at + 1]) in
        if v >= 32768 then v - 65536 else v
      in
      match s.[i] with
      | 'a' ->
          let w = arg 3 - arg 1 and h = arg 4 - arg 2 in
          if w <= 0 || h <= 0 || w > 2048 || h > 2048 then raise (Graphics "an image of no size, or too large");
          if List.exists (fun (k, _) -> k = arg 0) c.images then release c (arg 0);
          let made = { r = rect (arg 1) (arg 2) (arg 3) (arg 4); at = alloc (w * h); repl = arg 5 <> 0 } in
          row_fill made.at (arg 6 land 255) (w * h);
          c.images <- (arg 0, made) :: c.images;
          next (i + 15)
      | 'f' -> release c (arg 0); next (i + 3)
      | 'c' -> !cursor_hook (arg 0); next (i + 3)
      | 'd' ->
          let mask = if arg 2 < 0 then None else Some (find c (arg 2)) in
          draw (find c (arg 0)) (rect (arg 3) (arg 4) (arg 5) (arg 6)) (find c (arg 1)) mask (arg 7) (arg 8);
          next (i + 19)
      | 'l' -> line (find c (arg 0)) (arg 2) (arg 3) (arg 4) (arg 5) (find c (arg 1)); next (i + 13)
      | 's' ->
          let len = arg 4 in
          if len < 0 || i + 11 + len > n then raise (Graphics "a message cut short");
          text (find c (arg 0)) (arg 2) (arg 3) (find c (arg 1)) c.font (String.sub s (i + 11) len);
          next (i + 11 + len)
      | 't' ->
          let len = arg 4 in
          if len < 0 || i + 13 + len > n then raise (Graphics "a message cut short");
          styled (find c (arg 0)) (arg 2) (arg 3) (find c (arg 1)) c.font (arg 5) (String.sub s (i + 13) len);
          next (i + 13 + len)
      | 'p' ->
          let len = arg 3 in
          if len < 0 || i + 9 + len > n then raise (Graphics "a message cut short");
          pixels (find c (arg 0)) (arg 1) (arg 2) s (i + 9) len;
          next (i + 9 + len)
      | _ -> raise (Graphics "an unknown message")
    end
  in
  next 0
