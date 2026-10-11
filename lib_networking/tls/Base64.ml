(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/core/Base64.ml (docs/plans/plan_browser.md) *)

(* See Base64.mli *)

let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

(* the 6 bits a character stands for; -1 for the padding and anything
 * else (skipped, see the .mli) *)
let value (c : char) : int =
  match c with
  | 'A' .. 'Z' -> Char.code c - Char.code 'A'
  | 'a' .. 'z' -> Char.code c - Char.code 'a' + 26
  | '0' .. '9' -> Char.code c - Char.code '0' + 52
  | '+' -> 62
  | '/' -> 63
  | _ -> -1

(* The bits arrive 6 at a time and leave 8 at a time, so they are kept
 * in [bits], a few at a time, and a byte comes out whenever 8 of them
 * have piled up:
 *
 *     in    | 010011 | 010110 | 000101 | 101110 |
 *     bits  6   ->  12  ->  18  ->  24
 *     out       |01001101|01100001|01101110|
 *)
let values : int array = Array.init 256 (fun c -> value (Char.chr c))

(* opti: four characters at a time while they are all of the alphabet
 * (a PEM file's lines joined are): three bytes set from four values of
 * a table, no state between; the rest, from the first character that
 * is not (the padding, a space), by the bits kept as before. A system's
 * roots are 180,000 characters decoded at each start of a program that
 * asks for https://, 350 instructions each by mini-ml for arm.
 * old: String.iter (fun c -> let v = value c in if v >= 0 then begin
 *        acc := (!acc lsl 6) lor v; bits := !bits + 6;
 *        if !bits >= 8 then begin bits := !bits - 8;
 *          Buffer.add_char out (Char.chr ((!acc lsr !bits) land 0xFF)) end end) s *)
let decode (s : string) : string =
  let len = String.length s in
  let out = Bytes.create (len * 3 / 4) in
  let rec fours (i : int) (n : int) : int * int =
    if i + 4 > len then (i, n)
    else
      let a = values.(Char.code s.[i]) and b = values.(Char.code s.[i + 1]) and c = values.(Char.code s.[i + 2]) and d = values.(Char.code s.[i + 3]) in
      if a lor b lor c lor d < 0 then (i, n)
      else begin
        Bytes.set out n (Char.chr ((a lsl 2) lor (b lsr 4)));
        Bytes.set out (n + 1) (Char.chr (((b land 15) lsl 4) lor (c lsr 2)));
        Bytes.set out (n + 2) (Char.chr (((c land 3) lsl 6) lor d));
        fours (i + 4) (n + 3)
      end
  in
  let start, written = fours 0 0 in
  let acc = ref 0 and bits = ref 0 and n = ref written in
  for i = start to len - 1 do
    let v = values.(Char.code s.[i]) in
    if v >= 0 then begin
      (* (the bits not yet written, 13 at most: within any int) *)
      acc := ((!acc lsl 6) lor v) land 0x3fff;
      bits := !bits + 6;
      if !bits >= 8 then begin
        bits := !bits - 8;
        Bytes.set out !n (Char.chr ((!acc lsr !bits) land 0xFF));
        incr n
      end
    end
  done;
  Bytes.sub_string out 0 !n

let encode (s : string) : string =
  let out = Buffer.create ((String.length s + 2) / 3 * 4) in
  let n = String.length s in
  let byte i = if i < n then Char.code s.[i] else 0 in
  let rec go i =
    if i < n then begin
      let group = (byte i lsl 16) lor (byte (i + 1) lsl 8) lor byte (i + 2) in
      let char k = alphabet.[(group lsr (18 - (6 * k))) land 63] in
      Buffer.add_char out (char 0);
      Buffer.add_char out (char 1);
      Buffer.add_char out (if i + 1 < n then char 2 else '=');
      Buffer.add_char out (if i + 2 < n then char 3 else '=');
      go (i + 3)
    end
  in
  go 0;
  Buffer.contents out
