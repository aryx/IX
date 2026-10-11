(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Memgeneral.mli *)

open Memimage

let w (x0, _, x1, _) = x1 - x0
let h (_, y0, _, y1) = y1 - y0

(* MUL: x*y/255, memdraw's rounding *)
let mul x y = let t = (x * y) + 128 in (t + (t lsr 8)) lsr 8

(* the ops (draw.h's Drawop) *)
let o_clear = 0 and o_douts = 1 and o_souts = 2 and o_dins = 4 and o_d = 5 and o_datops = 6
and o_dovers = 7 and o_sind = 8 and o_satopd = 9 and o_s = 10 and o_soverd = 11

(* a mask's coverage of a pixel: its alpha, or else its grey *)
let coverage mask (mr, mg, mb, ma) =
  if mask.chan.Memchan.alpha then ma
  else if mask.chan.Memchan.grey || mask.chan.Memchan.depth < 8 then mr
  else Memchan.rgb2k mr mg mb

(* the general loop: every pixel read, composed, written *)
let general dst r src sr mask mr op =
        let (x0, y0, _, _) = r and (sx0, sy0, _, _) = sr and (mx0, my0, _, _) = mr in
        let dx = w r and dy = h r in
        let grey = dst.chan.Memchan.grey in
        let (sa0, sb0, sa1, sb1) = src.r and (ma0, mb0, ma1, mb1) = mask.r in
        (* the same memory, the destination below: bottom up (needbuf) *)
        let up = src.data == dst.data && byteaddr dst x0 y0 > byteaddr src sx0 sy0 in
        let sc = Array.make dx (0, 0, 0, 0) and mc = Array.make dx 0 in
        for j = 0 to dy - 1 do
          let j = if up then dy - 1 - j else j in
          let y = y0 + j in
          let sy = sb0 + ((sy0 - sb0 + j) mod (sb1 - sb0)) and my = mb0 + ((my0 - mb0 + j) mod (mb1 - mb0)) in
          (* the row's source and mask first (their pixels wrap in a repl image) *)
          let sx = ref sx0 and mx = ref mx0 in
          for i = 0 to dx - 1 do
            sc.(i) <- read src !sx sy;
            mc.(i) <- coverage mask (read mask !mx my);
            incr sx; if !sx = sa1 then sx := sa0;
            incr mx; if !mx = ma1 then mx := ma0
          done;
          for i = 0 to dx - 1 do
            let x = x0 + i in
            let (sr, sg, sb, sa) = sc.(i) and ma = mc.(i) in
            (* a grey destination: the source's grey (RGB2K), unless grey *)
            let sk = if src.chan.Memchan.grey || src.chan.Memchan.depth < 8 then sr else Memchan.rgb2k sr sg sb in
            if op <> o_d then begin
              let (dr, dg, db, da) = read dst x y in
              let dk = dr in
              let fs, fd =
                if op = o_clear then 0, 0
                else if op = o_douts || op = o_dins then
                  (0, let f = mul sa ma in if op = o_douts then 255 - f else f)
                else if op = o_souts || op = o_sind || op = o_s then
                  ((if op = o_s then ma else mul ma (if op = o_souts then 255 - da else da)), 0)
                else if op = o_soverd then (ma, 255 - mul sa ma)
                else
                  ((if op = o_satopd then mul ma da else mul ma (255 - da)),
                   (if op = o_dovers then 255 else let f = mul sa ma in if op <> o_datops then 255 - f else f)) in
              let c s d = mul fs s + mul fd d in
              write dst x y (c sr dr, c sg dg, c sb db, c sa da) (c sk dk)
            end
          done
        done
