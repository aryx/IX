(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Memdraw's path for a colour through a mask of a byte a pixel (a
 * smoothed letter: fast_grey) against the general loop, the same
 * draws on two copies of an image: the bytes are to be the same. The
 * screen's format (r5g6b5, the path's own arithmetic), x8r8g8b8 and
 * k8 (by read and write); half the destinations one byte repeated (a
 * page's background: the blends the path keeps), half noise; the
 * masks' pixels 0, 255 or between. In x8r8g8b8 the unused byte is 0:
 * the general loop writes every pixel, 0 there, where the path leaves
 * those the mask does not cover. Run by run.sh. *)

open Memimage

let chan hi lo = Option.get (Memchan.make hi lo)
let rgb16 = chan 0x0005 0x1625 and k8 = chan 0 0x38 and rgba = chan 0x0818 0x2848 and xrgb = chan 0x6808 0x1828

let test (dchan : Memchan.t) (name : string) : int =
  let fails = ref 0 in
  for trial = 1 to 200 do
    let w = 1 + Random.int 30 and h = 1 + Random.int 20 in
    let dst = alloc (0, 0, 40, 30) dchan in
    let bg = Random.int 256 in
    Bytes.iteri (fun i _ -> Bytes.set dst.data.bytes i (Char.chr (if trial mod 2 = 0 then bg else Random.int 256))) dst.data.bytes;
    if dchan == xrgb then Bytes.iteri (fun i _ -> if i mod 4 = 3 then Bytes.set dst.data.bytes i '\000') dst.data.bytes;
    let dst2 = alloc (0, 0, 40, 30) dchan in
    Bytes.blit dst.data.bytes 0 dst2.data.bytes 0 (Bytes.length dst.data.bytes);
    let mask = alloc (0, 0, w, h) k8 in
    Bytes.iteri (fun i _ -> Bytes.set mask.data.bytes i (Char.chr (match Random.int 3 with 0 -> 0 | 1 -> 255 | _ -> Random.int 256))) mask.data.bytes;
    let src = alloc (0, 0, 1, 1) rgba in
    src.repl <- true;
    src.clipr <- (-100000, -100000, 100000, 100000);
    write src 0 0 (Random.int 256, Random.int 256, Random.int 256, 255) 0;
    (* (partly outside the destination: the clip's) *)
    let x = Random.int 20 - 5 and y = Random.int 15 - 5 in
    let r = (x, y, x + w, y + h) in
    Memdraw.fast_grey := true;
    Memdraw.draw dst r src (0, 0) mask (0, 0) Memgeneral.o_soverd;
    Memdraw.fast_grey := false;
    Memdraw.draw dst2 r src (0, 0) mask (0, 0) Memgeneral.o_soverd;
    if not (Bytes.equal dst.data.bytes dst2.data.bytes) then incr fails
  done;
  Printf.printf "%s: %d of 200 draws differ\n" name !fails;
  !fails

let () =
  Random.init 7;
  let a = test rgb16 "r5g6b5" in
  let b = test xrgb "x8r8g8b8" in
  let c = test k8 "k8" in
  exit (if a + b + c = 0 then 0 else 1)
