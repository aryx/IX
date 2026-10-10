(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Tiny graphics: the essential of Plan 9's draw library (libdraw and
 * libmemdraw; ix's twins are lib_graphics/ and mini-9pi's
 * lib_memdraw), for tiny-machine's screen: 640 by 480 pixels, a byte
 * each, a colour of Plan 9's table. Not a program: TinyKernel.ml's part
 * that draws (plan_tiny_windows.md), in tiny-ml's ML, which is OCaml's
 * too, so that it is tested on the host first:
 *
 *     tiny-ml -tm -o kernel.tm memory.ml TinyGraphics.ml TinyKernel.ml   (TinyKernel/Makefile)
 *     dune build ./tiny/tests/TinyGraphics_tests/Host.exe     (TinyGraphics_test.sh)
 *
 * It asks five functions of bytes of its machine, TinyMemory's: peekb
 * and pokeb, and a row's three loops (copied, filled, a colour where a
 * mask is set), which are assembly on tiny-machine and an array's on
 * the host.
 *
 * What is kept of Plan 9's:
 *
 * - {b One operation}, [draw dst r src mask p]: the pixels of dst's
 *   rectangle r are src's from the point p on, where mask's are set
 *   (everywhere without one). A rectangle filled, a window copied to
 *   the screen, a text scrolled (an image drawn on itself), a
 *   character (the font is a mask, the ink the source) are all it.
 * - {b A colour is an image}, of one pixel, that repeats: so draw needs
 *   no colour argument, and a pattern costs nothing more.
 * - {b The kernel has the pixels, a program says what}: a program
 *   writes messages (a letter, then numbers of 16 bits) naming images
 *   by numbers of its own; [messages] decodes them for a connection.
 *   So a program draws without reaching the screen's memory, which
 *   TinyKernel.ml's partitions could not give it, and a window system
 *   forwards a program's messages after changing the numbers.
 *
 * Dropped: pixels of other depths and channels (one byte, the table's
 * index), alpha and Porter and Duff's operators (a mask is set or not),
 * a clipping rectangle apart from an image's own, a mask's own point
 * (it is the source's, as libdraw's draw), ellipses, arcs, polygons and
 * thick lines, fonts (one, the machine's 8 by 16) and their cache,
 * layers and windows (TinyWindows.ml composes whole images), the
 * screen's refresh.
 *
 * The messages, each a letter then 16-bit numbers, the low byte first,
 * signed; an image 0 is the connection's own (its window, or the
 * screen):
 *
 *     a id x0 y0 x1 y1 repl colour    an image made, of that rectangle and colour
 *                                     (the one that had this number freed)
 *     f id                            freed
 *     d dst src mask x0 y0 x1 y1 px py      draw (mask -1: none)
 *     l dst src x0 y0 x1 y1           a line, both ends drawn
 *     s dst src x y n, n bytes        a text, its top left corner at (x, y)
 *
 * Exercises:
 * - a row copied a word at a time where it can (draw.tm's row_copy);
 * - ellipses and filled polygons, for the playground's shapes;
 * - a mask of levels, 0 to 255: a pixel mixed, and a font with grey
 *   edges;
 * - a clipping rectangle per image, set by a message (a window's part
 *   that shows).
 *
 * References (from memory): R. Pike, "Graphics in Overlapping Bitmap
 * Layers" (ACM TOG 1983), the Blit's bitblt; R. Pike et al., "Plan 9
 * from Bell Labs" (1995) and draw(2), draw(3): the one operation, an
 * image a file's number; T. Porter and T. Duff, "Compositing Digital
 * Images" (SIGGRAPH 1984), what a mask of levels would bring; J.
 * Bresenham, "Algorithm for computer control of a digital plotter"
 * (IBM Systems Journal 1965), the line. *)

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
 * has too). Made a mask once: a byte a pixel, the characters side by
 * side in an image of 1024 by 16, so that a character is a draw. *)
let font_mask bits at =
  for c = 0 to 127 do
    for row = 0 to 15 do
      for col = 0 to 7 do pokeb (at + (row * 1024) + (c * 8) + col) ((peekb (bits + (c * 16) + row) lsr col) land 1) done
    done
  done;
  { r = rect 0 0 1024 16; at = at; repl = false }

(* a text, its top left corner at (x, y): each character the ink src
 * through the font's mask (a byte beyond the font's 128 is a ?) *)
let text (dst : image) x y (src : image) (font : image) s =
  for i = 0 to String.length s - 1 do
    let c = Char.code s.[i] in
    draw dst (rect (x + (8 * i)) y (x + (8 * i) + 8) (y + 16)) src (Some font) (8 * if c > 127 then 63 else c) 0
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
      | _ -> raise (Graphics "an unknown message")
    end
  in
  next 0
