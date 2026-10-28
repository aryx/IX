(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Makes tiny.font (README.md) from a TrueType font: its regular and its
 * bold, each at 8 by 16 and 16 by 32, the first 128 characters, a pixel
 * set or not; or grey.font, the same with grey edges, a pixel one of
 * four levels. ix's own reader and filler draw the letters (Truetype,
 * Outline, Fill.scan), as a PDF's are drawn; FreeType is not needed.
 *
 * Neither runs the font's hinting, the programs that move a letter's
 * points onto the pixels at a small size: a stem one pixel and a third
 * wide, where it falls, is drawn one pixel or two, and the top of an
 * e, a part of two rows, is in neither. What stands for it here, as
 * FreeType's autohinter does:
 *
 * - up, the heights every letter shares made whole rows: the
 *   baseline, the lower case's top (the x's) and the capitals' (the
 *   H's), the heights between stretched to fit (old: one shift down
 *   of the whole face, as across: the e's top, a third of a row and
 *   half of the next, was lost, the author's "the top of e is
 *   missing");
 * - across, one shift of the whole face, an eighth of a pixel at a
 *   time, the one whose pixels are most nearly all in or all out (the
 *   least sum of c (1 - c), c a pixel's part covered): in a monospaced
 *   font the stems of most letters are at the same places of their
 *   cells, so one shift puts most of them on whole pixels;
 * - then each character's own shift by the same measure, across up to
 *   3/8 of a pixel from the face's (too little to be seen in the
 *   spacing), and down, by as much, for what is no letter nor digit
 *   (a letter's rows are the heights above): with the face's alone, an
 *   E's and an L's stem straddled two pixels, two wide, and the +'s
 *   bar two rows, in neither.
 *
 * A pixel is then set where [enough] of it is covered; in grey.font the
 * others are grey by how much of them is.
 *
 * Run by hand; tiny.font and grey.font are kept in the repository, so
 * the build needs neither this nor the TrueType files. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let help = {|usage: Mkfont.exe [-grey] regular.ttf bold.ttf out.font
       Mkfont.exe -coverage c file.ttf
tiny-kernel's font of a TrueType font's regular and bold: 128 characters
of 8 by 16 each, then 16 by 32, a pixel set or not (fonts/README.md);
with -grey, a pixel one of 4 levels, grey at the letters' edges.
  dune exec tiny/TinyKernel/fonts/Mkfont.exe -- \
    UbuntuMono-Regular.ttf UbuntuMono-Bold.ttf tiny.font
  dune exec tiny/TinyKernel/fonts/Mkfont.exe -- -grey \
    UbuntuMono-Regular.ttf UbuntuMono-Bold.ttf grey.font
With -coverage, the character c at 8 by 16 as it is made: its pixels'
parts covered, in tenths (9 a whole one), the face's shift, and the
pixels set beside them.
|}

(* sub-rows a pixel's row is sampled at (across, the spans are exact) *)
let subrows = 8

(* the part of a pixel covered for it to be set: at a half, a stem of
 * Ubuntu Mono's regular at 16 pixels, a pixel and a little, was two
 * pixels wide wherever it straddled two (E, F, L, T heavy, the others
 * not); at 0.7 strokes broke (an r of two pieces); at 0.6 most stems
 * are one pixel and none broke, near FreeType's hinted letters
 * (preview.py) *)
let enough = 0.6

(* a face: the font, its scale (pixels a unit), the cell's size, the
 * baseline's row; the x's height and the H's, in the font's units, and
 * the whole rows they are made *)
type face = {
  font : Truetype.t; scale : float; w : int; h : int; base : float;
  xh : float; xrows : float; cap : float; caprows : float;
}

(* the pixels above the baseline of a height of the font's: up to the
 * x's, to the H's, above it (the accents, an f's top), each part
 * scaled to its rows, and the descenders as the lower case *)
let height (face : face) (y : float) : float =
  if y <= face.xh then y *. face.xrows /. face.xh
  else if y <= face.cap then
    face.xrows +. ((y -. face.xh) *. (face.caprows -. face.xrows) /. (face.cap -. face.xh))
  else face.caprows +. ((y -. face.cap) *. face.scale)

(* [coverage face c dx dy]: each pixel's part covered of character c in
 * its cell, w by h, row after row, shifted by (dx, dy); and how much of
 * it fell outside the cell across, lost *)
let coverage (face : face) (c : int) (dx : float) (dy : float) : float array * float =
  let cov = Array.make (face.w * face.h) 0. in
  let spill = ref 0. in
  let glyph =
    match Truetype.cmap face.font ~platform:3 ~encoding:1 with
    | Some f -> f c
    | None -> failwith "no Unicode cmap"
  in
  let contours =
    Outline.polygons ~tolerance:0.02
      (fun (x, y) ->
        ( (x *. face.scale) +. dx,
          (face.base -. height face y +. dy) *. float_of_int subrows ))
      (Truetype.outline face.font glyph)
  in
  Fill.scan ~rule:Fill.Nonzero ~height:(face.h * subrows) contours
    ~on_span:(fun ~y xa xb ->
      let row = y / subrows in
      if y >= 0 then begin
        let sub = float_of_int subrows in
        spill := !spill +. ((max 0. (min xb 0. -. xa)
                             +. max 0. (xb -. max xa (float_of_int face.w))) /. sub);
        for px = max 0 (int_of_float (floor xa))
            to min (face.w - 1) (int_of_float (ceil xb) - 1) do
          let part = min xb (float_of_int (px + 1)) -. max xa (float_of_int px) in
          if part > 0. then
            cov.((row * face.w) + px) <-
              cov.((row * face.w) + px) +. (part /. sub)
        done
      end);
  (cov, !spill)

(* how far a coverage's pixels are from all in or all out, and what it
 * lost outside the cell, counted as all wrong (old: not counted: the
 * m moved left, its right stem half out of the cell, was the least
 * fuzz, and an rn) *)
let fuzz ((cov, spill) : float array * float) : float =
  Array.fold_left (fun sum v -> sum +. (v *. (1. -. min 1. v))) spill cov

(* the face's shift across of least fuzz, 0 to 7/8, its printable
 * characters' together *)
let shift (face : face) : float =
  let best = ref (0., infinity) in
  for i = 0 to 7 do
    let dx = float_of_int i /. 8. in
    let f = ref 0. in
    for c = 33 to 126 do f := !f +. fuzz (coverage face c dx 0.) done;
    if !f < snd !best then best := (dx, !f)
  done;
  fst !best

(* character c's coverage at its own shift of least fuzz, from the
 * face's dx, -3/8 to 3/8 across, and down when it is no letter nor
 * digit *)
let placed (face : face) (dx : float) (c : int) : float array =
  let ch = Char.chr c in
  let upright =
    (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9')
  in
  let best = ref (coverage face c dx 0., infinity) in
  for i = -3 to 3 do
    for j = (if upright then 0 else -3) to (if upright then 0 else 3) do
      let cov = coverage face c (dx +. (float_of_int i /. 8.)) (float_of_int j /. 8.) in
      let f = fuzz cov in
      (* (the least shift of equal fuzz: a blank's, the face's) *)
      if f < snd !best -. 1e-9 || (f < snd !best +. 1e-9 && i = 0 && j = 0) then
        best := (cov, f)
    done
  done;
  fst (fst !best)

(* the least part covered of a bar's pixel set though under [enough] *)
let bar = 0.4

(* [pixels face cov]: the pixels set of a character's coverage: those
 * covered [enough]; then a level bar a pixel thick that falls on two
 * rows, half in each, in neither (an A's crossbar, which a letter
 * cannot move down for, its rows the heights'): its upper row's pixel,
 * or its row more covered, where both are covered at least [bar] and
 * neither of the two is set, and so is a neighbour in its row (a bar is
 * pixels side by side; a lone one was the tail of a curve, a speck).
 * (Ubuntu Mono's m at 8 pixels reads nearly as an n: its middle stem
 * is short, by design, FreeType draws it so too; no stroke lost.) *)
let pixels (face : face) (cov : float array) : bool array =
  let at x y =
    if x < 0 || y < 0 || x >= face.w || y >= face.h then 0.
    else cov.((y * face.w) + x)
  in
  let set = Array.map (fun v -> v >= enough) cov in
  let on x y = x >= 0 && y >= 0 && x < face.w && y < face.h && set.((y * face.w) + x) in
  let split x y =
    let v = at x y in
    (not (on x y)) && v >= bar
    && not (on x (y - 1) || on x (y + 1))
    && ((v >= at x (y + 1) && v > at x (y - 1) && at x (y + 1) >= bar)
        || (v > at x (y + 1) && at x (y - 1) >= bar && v > at x (y - 1)))
  in
  let bars = ref [] in
  for y = 0 to face.h - 1 do
    for x = 0 to face.w - 1 do
      if split x y && (split (x - 1) y || split (x + 1) y) then
        bars := ((y * face.w) + x) :: !bars
    done
  done;
  List.iter (fun i -> set.(i) <- true) !bars;
  set

(* the level of a pixel of grey.font, 0 (none) to 3 (the ink): 3 where
 * tiny.font's pixel is set, else the part covered, rounded to thirds
 * (old: tiny.font's alone, a pixel set or not): the same letters, with
 * grey around them where the outline passes *)
let level (set : bool) (v : float) : int =
  if set then 3 else min 2 (int_of_float (Float.round (v *. 3.)))

(* a face's 128 characters as tiny.font has them, depth 1: a row
 * (w + 7) / 8 bytes, its left pixel the low bit of its first; or as
 * grey.font, depth 2: a pixel two bits, its level, a row w / 4 bytes *)
let bits (face : face) (depth : int) : string =
  let dx = shift face in
  let bytes = ((face.w * depth) + 7) / 8 in
  let b = Bytes.make (128 * face.h * bytes) '\000' in
  for c = 32 to 126 do
    let cov = placed face dx c in
    let set = pixels face cov in
    for row = 0 to face.h - 1 do
      for x = 0 to face.w - 1 do
        let p = (row * face.w) + x in
        let v = if depth = 1 then Bool.to_int set.(p) else level set.(p) cov.(p) in
        let i = (((c * face.h) + row) * bytes) + (x * depth / 8) in
        Bytes.set b i
          (Char.chr (Char.code (Bytes.get b i) lor (v lsl (x * depth mod 8))))
      done
    done
  done;
  Bytes.to_string b

(* the face of a font file whose characters are w pixels wide (its
 * advance, a monospaced font's: the M's), h tall, the baseline at
 * 13/16 of the cell (16: 3 rows for the descenders); the x's and the
 * H's heights each the nearest whole rows *)
let face (font : Truetype.t) (w : int) (h : int) : face =
  let glyph c =
    match Truetype.cmap font ~platform:3 ~encoding:1 with
    | Some f -> f (Char.code c)
    | None -> failwith "no Unicode cmap"
  in
  let top c =
    match Outline.bounds (Truetype.outline font (glyph c)) with
    | Some (_, _, _, y1) -> y1
    | None -> failwith "no outline"
  in
  let scale = float_of_int w /. float_of_int (Truetype.advance font (glyph 'M')) in
  let xh = top 'x' and cap = top 'H' in
  { font; scale; w; h; base = float_of_int (h * 13 / 16);
    xh; xrows = Float.round (xh *. scale); cap; caprows = Float.round (cap *. scale) }

let main (caps : < caps; .. >) (argv : string array) : int =
  try
    match Array.to_list argv |> List.tl with
    | args when List.mem "-h" args || List.mem "--help" args ->
        Console.print caps help; 0
    | [ "-coverage"; c; file ] when String.length c = 1 ->
        let f = face (Truetype.of_string (FS.read caps (Fpath.v file))) 8 16 in
        let dx = shift f in
        let cov = placed f dx (Char.code c.[0]) in
        let set = pixels f cov in
        (* a pixel's tenths covered, '.' for none *)
        let tenths v =
          if v < 0.05 then '.' else Char.chr (48 + min 9 (int_of_float (v *. 10.)))
        in
        Console.print caps
          (Printf.sprintf "shift %g, x's height %g rows, H's %g\n" dx f.xrows f.caprows);
        for y = 0 to f.h - 1 do
          let i x = (y * f.w) + x in
          Console.print caps
            (String.init f.w (fun x -> tenths cov.(i x)) ^ "  "
             ^ String.init f.w (fun x -> if set.(i x) then '#' else '.') ^ "\n")
        done;
        0
    | ([ regular; bold; out ] | [ "-grey"; regular; bold; out ]) as args ->
        let read f = Truetype.of_string (FS.read caps (Fpath.v f)) in
        let r = read regular and b = read bold in
        let depth = if List.hd args = "-grey" then 2 else 1 in
        FS.write caps (Fpath.v out)
          (String.concat ""
             [ bits (face r 8 16) depth; bits (face b 8 16) depth;
               bits (face r 16 32) depth; bits (face b 16 32) depth ]);
        0
    | _ ->
        Console.eprint caps
          "usage: Mkfont.exe regular.ttf bold.ttf out.font   (-h: how)\n";
        1
  with Sys_error m | Failure m -> Console.eprint caps ("Mkfont: " ^ m ^ "\n"); 1

let () =
  Cap.main (fun caps ->
    Logging.setup caps ~name:"Mkfont";
    CapStdlib.exit caps (main caps (CapSys.argv caps)))
