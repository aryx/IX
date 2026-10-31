(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/graphics/videos/tests/Unit_yuv.ml *)

(* Yuv: the worked examples of Yuv.mli, and what 4:2:0 costs, by PSNR *)

let t = Testo.create
let triple = Alcotest.(triple int int int)

(* a picture of [w] x [h] whose pixel (x, y) is [f x y] *)
let picture (w : int) (h : int) (f : int -> int -> int * int * int) : Rgba_image.t =
  let img = Rgba_image.create ~width:w ~height:h in
  for y = 0 to h - 1 do
    for x = 0 to w - 1 do
      let r, g, b = f x y and o = 4 * ((y * w) + x) in
      Bytes.set_uint8 img.rgba (o) (r);
      Bytes.set_uint8 img.rgba (o + 1) (g);
      Bytes.set_uint8 img.rgba (o + 2) (b);
      Bytes.set_uint8 img.rgba (o + 3) (255)
    done
  done;
  img

let test_worked () =
  Alcotest.check triple "red, full" (76, 85, 255) (Yuv.of_rgb Full (255, 0, 0));
  Alcotest.check triple "red, studio" (81, 90, 240) (Yuv.of_rgb Studio (255, 0, 0));
  Alcotest.check triple "white, full" (255, 128, 128) (Yuv.of_rgb Full (255, 255, 255));
  Alcotest.check triple "white, studio" (235, 128, 128) (Yuv.of_rgb Studio (255, 255, 255));
  Alcotest.check triple "black, studio: 16, not 0" (16, 128, 128) (Yuv.of_rgb Studio (0, 0, 0));
  (* and back: a gray exactly, a color within the rounding *)
  Alcotest.check triple "gray and back" (100, 100, 100) (Yuv.to_rgb Full (Yuv.of_rgb Full (100, 100, 100)));
  let r, g, b = Yuv.to_rgb Studio (Yuv.of_rgb Studio (255, 0, 0)) in
  if abs (r - 255) > 2 || g > 2 || b > 2 then Alcotest.failf "red and back: (%d, %d, %d)" r g b;
  (* a video's black shown as if full range: not black, the classic bug *)
  Alcotest.check triple "studio black read as full" (16, 16, 16) (Yuv.to_rgb Full (Yuv.of_rgb Studio (0, 0, 0)))

let test_checker () =
  (* red and blue in a 2 x 2 checker: four brightnesses, one purple *)
  let red = (255, 0, 0) and blue = (0, 0, 255) in
  let p = Yuv.of_image Full C420 (picture 2 2 (fun x y -> if (x + y) mod 2 = 0 then red else blue)) in
  Alcotest.(check (list int)) "Y kept" [ 76; 29; 29; 76 ] (List.init 4 (fun i -> Char.code (Bytes.get p.y i)));
  Alcotest.(check (pair int int)) "one Cb, one Cr" (170, 181) (Char.code (Bytes.get p.cb 0), Char.code (Bytes.get p.cr 0));
  (* the sizes: 1.5 bytes a pixel; an odd size rounds up *)
  Alcotest.(check (pair int int)) "320 x 240's color" (160, 120) (Yuv.chroma_size C420 ~width:320 ~height:240);
  Alcotest.(check (pair int int)) "an odd size" (3, 2) (Yuv.chroma_size C420 ~width:5 ~height:3)

let test_cost () =
  (* a smooth picture loses little to 4:2:0; sharp color edges lose much
   * (in color, the brightness kept) *)
  let smooth = picture 32 32 (fun x y -> (x * 8, y * 8, 128)) in
  let sharp = picture 32 32 (fun x y -> if (x + y) mod 2 = 0 then (255, 0, 0) else (0, 0, 255)) in
  let through range chroma img = Yuv.to_image range (Yuv.of_image range chroma img) in
  let db range chroma img = Psnr.psnr img (through range chroma img) in
  if db Full C444 smooth < 45. then Alcotest.failf "4:4:4, full: %.1f dB" (db Full C444 smooth);
  if db Studio C420 smooth < 35. then Alcotest.failf "a smooth picture through 4:2:0: %.1f dB" (db Studio C420 smooth);
  if db Studio C420 sharp > 15. then Alcotest.failf "a red and blue checker through 4:2:0: %.1f dB" (db Studio C420 sharp)

(* every pixel of a Y, Cb, Cr sweep: the whole numbers within one of the floats *)
let whole_within_one () =
  let w = 256 and h = 64 in
  let plane (f : int -> int) = Bytes.init (w * h) (fun i -> Char.chr (f i land 255)) in
  let check (range : Yuv.range) =
    let p : Yuv.planes =
      { width = w; height = h; chroma = C444; y = plane (fun i -> i); cb = plane (fun i -> i * 7 / 3); cr = plane (fun i -> i * 11 / 5) }
    in
    let a = Yuv.to_image_whole range p and b = Yuv.to_image_floats range p in
    Bytes.iteri
      (fun i c -> if abs (Char.code c - Bytes.get_uint8 b.rgba i) > 1 then Alcotest.failf "byte %d" i)
      a.rgba
  in
  check Studio;
  check Full

let tests =
  Testo.categorize "Yuv"
    [ t "whole numbers: within one of the floats" whole_within_one;
      t "red, white, black: Yuv.mli's numbers" test_worked; t "4:2:0: a red and blue checker becomes purple" test_checker; t "what 4:2:0 costs, measured" test_cost ]
