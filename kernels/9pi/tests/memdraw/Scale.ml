(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Memdraw.scale (the draw device's 'z': a picture k times larger)
 * against a pixel by pixel reference: each pixel of dst's rectangle,
 * inside its clip, is the source's at sp plus its offset divided by k,
 * when that is inside the source's rectangle and clip, and is left
 * as it was otherwise. The machine's loop is runtime.c's own
 * (imag_scale, run.sh compiles it): the formats of 2 and 4 bytes a
 * pixel (its loops of shorts and words) and 3 (its loop of bytes); k
 * from 1 to 5; the rectangle's start in the middle of a source
 * pixel's k by k (clipped by dst's rectangle or its clip). Run by
 * run.sh. *)

open Memimage

let chan hi lo = Option.get (Memchan.make hi lo)
let rgb16 = chan 0x0005 0x1625 and xrgb = chan 0x6808 0x1828 and rgb24 = chan 0x08 0x1828

let test (c : Memchan.t) (name : string) : int =
  let fails = ref 0 in
  let n = c.Memchan.depth / 8 in
  for _trial = 1 to 300 do
    let k = 1 + Random.int 5 in
    let noise (i : t) = Bytes.iteri (fun j _ -> Bytes.set i.data.bytes j (Char.chr (Random.int 256))) i.data.bytes in
    (* (the source's rectangle not at 0, 0, and clipped) *)
    let sx = Random.int 5 and sy = Random.int 5 in
    let src = alloc (sx, sy, sx + 3 + Random.int 20, sy + 3 + Random.int 15) c in
    noise src;
    let (a0, b0, a1, b1) = src.r in
    if Random.int 3 = 0 then src.clipr <- (a0 + 1, b0 + 1, a1 - 1, b1);
    let dst = alloc (0, 0, 70, 50) c in
    noise dst;
    if Random.int 3 = 0 then dst.clipr <- (3 + Random.int 5, 2 + Random.int 5, 60, 45);
    let before = Bytes.copy dst.data.bytes in
    let x = Random.int 30 - 8 and y = Random.int 20 - 8 in
    let r = (x, y, x + Random.int 60, y + Random.int 40) in
    let sp = (a0 + Random.int 3 - 1, b0 + Random.int 3 - 1) in
    if not (Memdraw.scale dst r src sp k) then incr fails
    else begin
      let inside (px, py) (x0, y0, x1, y1) = px >= x0 && px < x1 && py >= y0 && py < y1 in
      let (dx0, dy0, dx1, dy1) = dst.r in
      for py = dy0 to dy1 - 1 do
        for px = dx0 to dx1 - 1 do
          let (rx0, ry0, _, _) = r in
          let at = byteaddr dst px py in
          let s = (fst sp + ((px - rx0) / k), snd sp + ((py - ry0) / k)) in
          let expected =
            if inside (px, py) r && inside (px, py) dst.clipr && px >= rx0 && py >= ry0
               && inside s src.r && inside s src.clipr
            then Bytes.sub src.data.bytes (byteaddr src (fst s) (snd s)) n
            else Bytes.sub before at n in
          if not (Bytes.equal expected (Bytes.sub dst.data.bytes at n)) then incr fails
        done
      done
    end
  done;
  Printf.printf "%s: %d pixels of 300 scaled draws differ\n" name !fails;
  !fails

let () =
  Random.init 7;
  let a = test rgb16 "r5g6b5" in
  let b = test xrgb "x8r8g8b8" in
  let c = test rgb24 "r8g8b8" in
  (* not the same chan: refused *)
  let d = if Memdraw.scale (alloc (0, 0, 4, 4) rgb16) (0, 0, 4, 4) (alloc (0, 0, 2, 2) xrgb) (0, 0) 2 then 1 else 0 in
  exit (if a + b + c + d = 0 then 0 else 1)
