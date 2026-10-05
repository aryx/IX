(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Binary.mli *)

let u8 s o = Char.code s.[o]
let le16 s o = u8 s o lor (u8 s (o + 1) lsl 8)
let be16 s o = (u8 s o lsl 8) lor u8 s (o + 1)
let le32 s o = le16 s o lor (le16 s (o + 2) lsl 16)
let be32 s o = (be16 s o lsl 16) lor be16 s (o + 2)

let add_u8 b v = Buffer.add_char b (Char.chr (v land 0xff))
let add_le16 b v = add_u8 b v; add_u8 b (v lsr 8)
let add_be16 b v = add_u8 b (v lsr 8); add_u8 b v
(* asr: a negative number's high half is ones where an int has 31 bits *)
let add_le32 b v = add_le16 b v; add_le16 b (v asr 16)
let add_be32 b v = add_be16 b (v asr 16); add_be16 b v

let set_u8 b o v = Bytes.set b o (Char.chr (v land 0xff))
let set_le16 b o v = set_u8 b o v; set_u8 b (o + 1) (v lsr 8)
let set_le32 b o v = set_le16 b o v; set_le16 b (o + 2) (v asr 16)
let set_le b o width (n : int64) =
  for i = 0 to width - 1 do set_u8 b (o + i) (Int64.to_int (Int64.shift_right_logical n (8 * i))) done

type field = B of int | W of int | L of int | Q of int | S of string

let add_be64 b (n : int64) = for i = 7 downto 0 do add_u8 b (Int64.to_int (Int64.shift_right_logical n (8 * i))) done

let fields add16 add32 add64 (fs : field list) =
  let b = Buffer.create 64 in
  List.iter (function
    | B v -> add_u8 b v
    | W v -> add16 b v
    | L v -> add32 b v
    | Q v -> add64 b (Int64.of_int v)
    | S s -> Buffer.add_string b s) fs;
  Buffer.contents b

let le fs = fields add_le16 add_le32 Buffer.add_int64_le fs
let be fs = fields add_be16 add_be32 add_be64 fs
