(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Makes tiny.font (README.md) from a TrueType font: its regular and its
 * bold, each at 8 by 16 and 16 by 32, the first 128 characters, a pixel
 * set or not. ix's own reader and filler draw the letters (Truetype,
 * Outline, Fill.scan), as a PDF's are drawn; FreeType is not needed.
 *
 * Neither runs the font's hinting, the programs that move a letter's
 * points onto the pixels at a small size: a stem one pixel and a third
 * wide, where it falls, is drawn one pixel or two. What stands for it
 * here is one shift of the whole face, an eighth of a pixel at a time
 * across and down, the one whose pixels are most nearly all in or all
 * out (the least sum of c (1 - c), c a pixel's part covered): in a
 * monospaced font the stems of most letters are at the same places of
 * their cells, so one shift puts most of them on whole pixels. A pixel
 * is then set where [enough] of it is covered.
 *
 * Run by hand; tiny.font is kept in the repository, so the build
 * needs neither this nor the TrueType files. *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

let help = {|usage: Mkfont.exe regular.ttf bold.ttf out.font
       Mkfont.exe -coverage c file.ttf
tiny-kernel's font of a TrueType font's regular and bold: 128 characters
of 8 by 16 each, then 16 by 32, a pixel set or not (fonts/README.md).
  dune exec tiny/TinyKernel/fonts/Mkfont.exe -- \
    UbuntuMono-Regular.ttf UbuntuMono-Bold.ttf tiny.font
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
 * baseline's row *)
type face = { font : Truetype.t; scale : float; w : int; h : int; base : float }

(* [coverage face c dx dy]: each pixel's part covered of character c in
 * its cell, w by h, row after row, the face shifted by (dx, dy) *)
let coverage (face : face) (c : int) (dx : float) (dy : float) : float array =
  let cov = Array.make (face.w * face.h) 0. in
  let glyph =
    match Truetype.cmap face.font ~platform:3 ~encoding:1 with
    | Some f -> f c
    | None -> failwith "no Unicode cmap"
  in
  let contours =
    Outline.polygons ~tolerance:0.02
      (fun (x, y) ->
        ( (x *. face.scale) +. dx,
          (face.base -. (y *. face.scale) +. dy) *. float_of_int subrows ))
      (Truetype.outline face.font glyph)
  in
  Fill.scan ~rule:Fill.Nonzero ~height:(face.h * subrows) contours
    ~on_span:(fun ~y xa xb ->
      let row = y / subrows in
      if y >= 0 then
        for px = max 0 (int_of_float (floor xa))
            to min (face.w - 1) (int_of_float (ceil xb) - 1) do
          let part = min xb (float_of_int (px + 1)) -. max xa (float_of_int px) in
          if part > 0. then
            cov.((row * face.w) + px) <-
              cov.((row * face.w) + px) +. (part /. float_of_int subrows)
        done);
  cov

(* how far the printable characters' pixels are from all in or all out,
 * the face shifted by (dx, dy) *)
let fuzz (face : face) (dx : float) (dy : float) : float =
  let sum = ref 0. in
  for c = 33 to 126 do
    Array.iter (fun v -> sum := !sum +. (v *. (1. -. min 1. v)))
      (coverage face c dx dy)
  done;
  !sum

(* the shift of least fuzz: across 0 to 7/8, down -1/2 to 3/8 *)
let shift (face : face) : float * float =
  let best = ref (0., 0., infinity) in
  for i = 0 to 7 do
    for j = -4 to 3 do
      let dx = float_of_int i /. 8. and dy = float_of_int j /. 8. in
      let f = fuzz face dx dy in
      let _, _, b = !best in
      if f < b then best := (dx, dy, f)
    done
  done;
  let dx, dy, _ = !best in
  (dx, dy)

(* the pixels set of a character's coverage: those covered [enough].
 * (Ubuntu Mono's m at 8 pixels reads nearly as an n: its middle stem
 * is short, by design, FreeType draws it so too; it is no stroke lost,
 * which a dropout control as TrueType's would bring back.) *)
let pixels (cov : float array) : bool array = Array.map (fun v -> v >= enough) cov

(* a face's 128 characters as tiny.font has them: a row (w + 7) / 8
 * bytes, its left pixel the low bit of its first *)
let bits (face : face) : string =
  let dx, dy = shift face in
  let bytes = (face.w + 7) / 8 in
  let b = Bytes.make (128 * face.h * bytes) '\000' in
  for c = 32 to 126 do
    let set = pixels (coverage face c dx dy) in
    for row = 0 to face.h - 1 do
      for x = 0 to face.w - 1 do
        if set.((row * face.w) + x) then begin
          let i = (((c * face.h) + row) * bytes) + (x / 8) in
          Bytes.set b i
            (Char.chr (Char.code (Bytes.get b i) lor (1 lsl (x mod 8))))
        end
      done
    done
  done;
  Bytes.to_string b

(* the face of a font file whose characters are w pixels wide (its
 * advance, a monospaced font's: the M's), h tall, the baseline at
 * 13/16 of the cell (16: 3 rows for the descenders) *)
let face (font : Truetype.t) (w : int) (h : int) : face =
  let m =
    match Truetype.cmap font ~platform:3 ~encoding:1 with
    | Some f -> f (Char.code 'M')
    | None -> failwith "no Unicode cmap"
  in
  { font; scale = float_of_int w /. float_of_int (Truetype.advance font m);
    w; h; base = float_of_int (h * 13 / 16) }

let main (caps : < caps; .. >) (argv : string array) : int =
  try
    match Array.to_list argv |> List.tl with
    | args when List.mem "-h" args || List.mem "--help" args ->
        Console.print caps help; 0
    | [ "-coverage"; c; file ] when String.length c = 1 ->
        let f = face (Truetype.of_string (FS.read caps (Fpath.v file))) 8 16 in
        let dx, dy = shift f in
        let cov = coverage f (Char.code c.[0]) dx dy in
        let set = pixels cov in
        (* a pixel's tenths covered, '.' for none *)
        let tenths v =
          if v < 0.05 then '.' else Char.chr (48 + min 9 (int_of_float (v *. 10.)))
        in
        Console.print caps (Printf.sprintf "shift %g %g\n" dx dy);
        for y = 0 to f.h - 1 do
          let i x = (y * f.w) + x in
          Console.print caps
            (String.init f.w (fun x -> tenths cov.(i x)) ^ "  "
             ^ String.init f.w (fun x -> if set.(i x) then '#' else '.') ^ "\n")
        done;
        0
    | [ regular; bold; out ] ->
        let read f = Truetype.of_string (FS.read caps (Fpath.v f)) in
        let r = read regular and b = read bold in
        FS.write caps (Fpath.v out)
          (String.concat ""
             [ bits (face r 8 16); bits (face b 8 16);
               bits (face r 16 32); bits (face b 16 32) ]);
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
