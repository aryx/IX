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
let decode (s : string) : string =
  let out = Buffer.create (String.length s * 3 / 4) in
  let acc = ref 0 and bits = ref 0 in
  String.iter
    (fun c ->
      let v = value c in
      if v >= 0 then begin
        acc := (!acc lsl 6) lor v;
        bits := !bits + 6;
        if !bits >= 8 then begin
          bits := !bits - 8;
          Buffer.add_char out (Char.chr ((!acc lsr !bits) land 0xFF))
        end
      end)
    s;
  Buffer.contents out

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
