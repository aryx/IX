(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* clips/square.flc, which nothing else makes: a bright square moving over
 * two colours, what a delta frame is good at. usage: Make_fli file *)

let frame (k : int) : Rgba_image.t =
  let w = 32 and h = 24 in
  let img = Rgba_image.create ~width:w ~height:h in
  for y = 0 to h - 1 do
    for x = 0 to w - 1 do
      let inside = x >= k * 3 && x < (k * 3) + 8 && y >= 8 && y < 16 in
      let r, g, b = if inside then (250, 220, 40) else if y < 12 then (30, 60, 150) else (40, 120, 60) in
      let o = 4 * ((y * w) + x) in
      Bytes.set_uint8 img.rgba o r;
      Bytes.set_uint8 img.rgba (o + 1) g;
      Bytes.set_uint8 img.rgba (o + 2) b;
      Bytes.set_uint8 img.rgba (o + 3) 255
    done
  done;
  img

let () =
  let oc = open_out_bin Sys.argv.(1) in
  output_string oc (Fli_write.to_string ~delay:0.1 (List.init 8 frame));
  close_out oc
