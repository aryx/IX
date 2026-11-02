(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Paper.mli *)

let bands n c =
  let r = (c lsr 16) land 255 and g = (c lsr 8) land 255 and b = c land 255 in
  let at v k = v - (v * 2 * k / (3 * max 1 (n - 1))) in
  List.init n (fun k -> (at r k lsl 16) lor (at g k lsl 8) lor at b k)

let cover sw sh rgba w h =
  let out = Bytes.make (w * h * 4) '\000' in
  if sw > 0 && sh > 0 then begin
    (* the scale that covers: the larger of the two ratios, in 1/1024ths *)
    let k = max (w * 1024 / sw) (h * 1024 / sh) in
    let k = max k 1 in
    (* where the screen's corner is in the picture, the excess cut in halves *)
    let ox = ((sw * k / 1024) - w) / 2 and oy = ((sh * k / 1024) - h) / 2 in
    for y = 0 to h - 1 do
      let sy = min (sh - 1) ((y + oy) * 1024 / k) in
      for x = 0 to w - 1 do
        let sx = min (sw - 1) ((x + ox) * 1024 / k) in
        let s = ((sy * sw) + sx) * 4 and o = ((y * w) + x) * 4 in
        Bytes.set out o (Bytes.get rgba (s + 2));
        Bytes.set out (o + 1) (Bytes.get rgba (s + 1));
        Bytes.set out (o + 2) (Bytes.get rgba s)
      done
    done
  end;
  Bytes.to_string out
