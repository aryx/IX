(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Memfont.mli *)

type fontchar = { fx : int; top : int; bottom : int; left : int; width : int }

type t = { n : int; height : int; ascent : int; info : fontchar array; bits : Memimage.t }

(* atoi of a 12-byte field *)
let atoi s o =
  let rec go i v = if i < o + 12 && s.[i] >= '0' && s.[i] <= '9' then go (i + 1) ((v * 10) + Char.code s.[i] - 48) else v in
  let rec skip i = if i < o + 12 && s.[i] = ' ' then skip (i + 1) else i in
  go (skip o) 0

let default () =
  let s = Memdata.defont in
  let ld = atoi s 0 in
  let r = (atoi s 12, atoi s 24, atoi s 36, atoi s 48) in
  (* drawld2chan: an old ldepth's chan: GREY1, GREY2, GREY4, CMAP8 *)
  let chan = match Memchan.make 0 (List.nth [ 0x31; 0x32; 0x34; 0x58 ] ld) with Some c -> c | None -> failwith "defont" in
  let img = Memimage.alloc r chan in
  let (_, y0, _, y1) = r in
  let size = (y1 - y0) * img.Memimage.bwidth in
  img.Memimage.data.Memimage.bytes <- Bytes.unsafe_of_string (String.sub s 60 size);
  let hdr = 60 + size in
  let n = atoi s hdr in
  (* _unpackinfo: x (2 bytes), top, bottom, left (signed), width *)
  let b k = Char.code s.[k] in
  let info = Array.init (n + 1) (fun j ->
    let p = hdr + 36 + (6 * j) in
    { fx = b p lor (b (p + 1) lsl 8); top = b (p + 2); bottom = b (p + 3);
      left = (let v = b (p + 4) in if v >= 128 then v - 256 else v); width = b (p + 5) }) in
  { n = n; height = atoi s (hdr + 12); ascent = atoi s (hdr + 24); info = info; bits = img }

(* chartorune: a rune and its bytes (a bad one Runeerror, one byte) *)
let rune s i =
  let n = String.length s in
  let c = Char.code s.[i] in
  let cont k = i + k < n && Char.code s.[i + k] land 0xc0 = 0x80 in
  let v k = Char.code s.[i + k] land 0x3f in
  if c < 0x80 then (c, 1)
  else if c land 0xe0 = 0xc0 && cont 1 then (((c land 0x1f) lsl 6) lor v 1, 2)
  else if c land 0xf0 = 0xe0 && cont 1 && cont 2 then (((c land 0x0f) lsl 12) lor (v 1 lsl 6) lor v 2, 3)
  else (0xfffd, 1)

let fold f s acc =
  let rec go i acc = if i >= String.length s then acc else let (c, k) = rune s i in go (i + k) (f c acc) in
  go 0 acc

let string draw dst (px, py) src (cx, cy) f s =
  let (x, _, _) =
    fold (fun c (x, cx, _) ->
      if c >= f.n then (x, cx, ())
      else begin
        let i = f.info.(c) in
        draw dst (x + i.left, py + i.top, x + i.left + (f.info.(c + 1).fx - i.fx), py + i.bottom)
          src (cx, cy) f.bits (i.fx, i.top) 11;
        (x + i.width, cx + i.width, ())
      end) s (px, cx, ()) in
  (x, py)

let width f s = fold (fun c x -> if c >= f.n then x else x + f.info.(c).width) s 0
