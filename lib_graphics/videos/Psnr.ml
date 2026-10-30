(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Psnr.mli *)
(* ix: the author's playground's libs/graphics/videos/yuv/Psnr.ml *)

let mse (a : Rgba_image.t) (b : Rgba_image.t) : float =
  if a.width <> b.width || a.height <> b.height then invalid_arg "Psnr.mse: not the same size";
  let sum = ref 0 in
  for i = 0 to (a.width * a.height) - 1 do
    for c = 0 to 2 do
      let d = Bytes.get_uint8 a.rgba ((4 * i) + c) - Bytes.get_uint8 b.rgba ((4 * i) + c) in
      sum := !sum + (d * d)
    done
  done;
  float_of_int !sum /. float_of_int (3 * a.width * a.height)

let of_mse (e : float) : float = if e = 0. then infinity else 10. *. log10 (255. *. 255. /. e)
let psnr (a : Rgba_image.t) (b : Rgba_image.t) : float = of_mse (mse a b)
