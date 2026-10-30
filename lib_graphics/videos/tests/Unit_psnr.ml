(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/graphics/videos/tests/Unit_psnr.ml *)

(* Psnr: Psnr.mli's worked example *)

let t = Testo.create

let gray (w : int) (v : int) : Rgba_image.t =
  let img = Rgba_image.create ~width:w ~height:w in
  Bytes.fill img.rgba 0 (Bytes.length img.rgba) (Char.chr v);
  img

let test_worked () =
  let a = gray 8 100 in
  Alcotest.(check (float 1e-9)) "off by 2: MSE 4" 4. (Psnr.mse a (gray 8 102));
  Alcotest.(check (float 0.05)) "42.1 dB" 42.1 (Psnr.psnr a (gray 8 102));
  Alcotest.(check (float 0.05)) "off by 16: 24.0 dB" 24.05 (Psnr.psnr a (gray 8 84));
  Alcotest.(check (float 0.)) "the same: infinitely far from noise" infinity (Psnr.psnr a (gray 8 100))

let tests = Testo.categorize "Psnr" [ t "off by 2, off by 16" test_worked ]
