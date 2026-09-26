(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Memchan.mli *)

type t = { hi : int; lo : int; chans : (int * int * int) list; depth : int; grey : bool; alpha : bool; cmap : bool }

let cred = 0 and cgreen = 1 and cblue = 2 and cgrey = 3 and calpha = 4 and cmapped = 5 and cignore = 6

(* the chan's bytes, top first, those not 0; each a channel: its type in
 * the high nibble, its bits in the low one *)
let make hi lo =
  let bytes = List.filter (fun b -> b <> 0) [ hi lsr 8; hi land 255; lo lsr 8; lo land 255 ] in
  let d = List.fold_left (fun d b -> d + (b land 15)) 0 bytes in
  if bytes = [] || List.exists (fun b -> b lsr 4 > cignore || b land 15 = 0) bytes
     || (d > 8 && d mod 8 <> 0) || (d < 8 && 8 mod d <> 0) then None
  else begin
    (* the shifts, from the last channel (the pixel's low bits) up *)
    let rec place = function
      | [] -> [], 0
      | b :: rest -> let l, s = place rest in (b lsr 4, b land 15, s) :: l, s + (b land 15) in
    let chans = fst (place bytes) in
    let has t = List.exists (fun (t', _, _) -> t' = t) chans in
    Some { hi = hi; lo = lo; chans = chans; depth = d; grey = has cgrey; alpha = has calpha; cmap = has cmapped }
  end

let name c =
  String.concat "" (List.map (fun (t, n, _) -> String.make 1 "rgbkamx".[t] ^ string_of_int n) c.chans)

(* imgtorgba's doubling: the bits beside themselves until 8, the top 8 *)
let repl n v =
  let rec go v n = if n >= 8 then v lsr (n - 8) else go (v lor (v lsl n)) (2 * n) in
  go v n

let rgb2k r g b = ((156763 * r) + (307758 * g) + (59769 * b)) lsr 19

let cmap2rgb i = (Char.code Memdata.cmap2rgb.[3 * i], Char.code Memdata.cmap2rgb.[(3 * i) + 1], Char.code Memdata.cmap2rgb.[(3 * i) + 2])
let rgb2cmap r g b = Char.code Memdata.rgb2cmap.[((r lsr 4) * 256) + ((g lsr 4) * 16) + (b lsr 4)]
