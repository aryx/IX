(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Utf8.mli *)

let decode s o =
  let d = String.get_utf_8_uchar s o in
  Uchar.to_int (Uchar.utf_decode_uchar d), Uchar.utf_decode_length d

(* (a number that is no character's, a surrogate's, is written as it is) *)
let add b c = Buffer.add_utf_8_uchar b (Uchar.unsafe_of_int c)

let size s o = snd (decode s o)

let chars s =
  let rec go o acc =
    if o >= String.length s then List.rev acc, ""
    else
      let d = String.get_utf_8_uchar s o in
      let n = Uchar.utf_decode_length d in
      (* bytes that are no character, up to the end: one's start *)
      if not (Uchar.utf_decode_is_valid d) && o + n = String.length s && s.[o] >= '\xc0' && s.[o] < '\xf8' then List.rev acc, String.sub s o n
      else go (o + n) (String.sub s o n :: acc) in
  go 0 []

(* where the character of number k after o starts (the end, past the last) *)
let rec start s k o = if k <= 0 || o >= String.length s then o else start s (k - 1) (o + size s o)

let length s =
  let rec go o n = if o >= String.length s then n else go (o + size s o) (n + 1) in
  go 0 0

let sub s from n =
  let a = start s from 0 in
  String.sub s a (start s n a - a)

let code c = fst (decode c 0)

(* blocks, each its first and last character *)
let wide : (int * int) array = [|
  0x1100, 0x115F; 0x231A, 0x231B; 0x23E9, 0x23EC; 0x2614, 0x2615; 0x2648, 0x2653; 0x26A1, 0x26A1; 0x2705, 0x2705;
  0x274C, 0x274C; 0x2753, 0x2755; 0x2795, 0x2797; 0x2B50, 0x2B50; 0x2E80, 0x303E; 0x3041, 0x33FF; 0x3400, 0x4DBF;
  0x4E00, 0x9FFF; 0xA000, 0xA4CF; 0xA960, 0xA97F; 0xAC00, 0xD7A3; 0xF900, 0xFAFF; 0xFE30, 0xFE6F; 0xFF00, 0xFF60;
  0xFFE0, 0xFFE6; 0x1F300, 0x1F64F; 0x1F680, 0x1F6FF; 0x1F900, 0x1F9FF; 0x1FA70, 0x1FAFF; 0x20000, 0x3FFFD;
|]

let zero : (int * int) array = [|
  0x0300, 0x036F; 0x0483, 0x0489; 0x0591, 0x05BD; 0x0610, 0x061A; 0x064B, 0x065F; 0x0E31, 0x0E31; 0x0E34, 0x0E3A;
  0x0E47, 0x0E4E; 0x1AB0, 0x1AFF; 0x1DC0, 0x1DFF; 0x200B, 0x200F; 0x20D0, 0x20FF; 0x3099, 0x309A; 0xFE00, 0xFE0F;
  0xFE20, 0xFE2F; 0xE0100, 0xE01EF;
|]

let among (blocks : (int * int) array) (c : int) : bool =
  let found = ref false in
  Array.iter (fun ((first, last) : int * int) -> if c >= first && c <= last then found := true) blocks;
  !found

let width (c : int) : int = if c < 0x300 then 1 else if among zero c then 0 else if among wide c then 2 else 1
