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
