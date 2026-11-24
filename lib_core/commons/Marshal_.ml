(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Marshal_.mli. The codes are OCaml's (runtime/caml/intext.h);
 * lib_core/core/Marshal.ml says what each one is followed by. *)

exception Unknown

(* the big-endian number of n bytes at i *)
let number (s : bytes) (i : int) (n : int) : int =
  let v = ref 0 in
  for k = 0 to n - 1 do
    v := (!v lsl 8) lor Char.code (Bytes.get s (i + k))
  done;
  !v

let clear_color (s : bytes) (i : int) : unit =
  Bytes.set s i (Char.chr (Char.code (Bytes.get s i) land 0xFC))

(* the bytes after the code at i, a header's color bits cleared *)
let skip (s : bytes) (i : int) : int =
  let c = Char.code (Bytes.get s i) in
  if c >= 0x40 then i + 1
  else if c >= 0x20 then i + 1 + (c - 0x20)
  else
    match c with
    | 0x00 | 0x04 -> i + 2
    | 0x01 | 0x05 -> i + 3
    | 0x02 | 0x06 -> i + 5
    | 0x03 | 0x14 | 0x0B | 0x0C -> i + 9
    (* a block's header: the color is the low bits of its byte 2 of 4,
     * or 6 of 8 *)
    | 0x08 -> clear_color s (i + 3); i + 5
    | 0x13 -> clear_color s (i + 7); i + 9
    | 0x09 -> i + 2 + number s (i + 1) 1
    | 0x0A -> i + 5 + number s (i + 1) 4
    | 0x15 -> i + 9 + number s (i + 1) 8
    | 0x0D | 0x0E -> i + 2 + 8 * number s (i + 1) 1
    | 0x07 | 0x0F -> i + 5 + 8 * number s (i + 1) 4
    | 0x16 | 0x17 -> i + 9 + 8 * number s (i + 1) 8
    | 0x12 | 0x19 ->
        let e = Bytes.index_from s (i + 1) '\000' in
        (match Bytes.sub_string s (i + 1) (e - i - 1) with
         | "_j" -> e + 9
         | "_i" -> e + 5
         | _ -> raise Unknown)
    | _ -> raise Unknown

let clean (m : string) : string =
  let s = Bytes.of_string m in
  (* the data's start: after the small header, or the big one (OCaml 5,
   * for data of 4 GB or more) *)
  let start =
    match String.sub m 0 4 with
    | "\x84\x95\xA6\xBE" -> 20
    | "\x84\x95\xA6\xBF" -> 32
    | _ -> raise Unknown
  in
  let i = ref start in
  while !i < Bytes.length s do
    i := skip s !i
  done;
  Bytes.unsafe_to_string s

(* whether this program's Marshal writes the color bits *)
let colored : bool =
  let m = Marshal.to_string (Array.make 8 0) [ Marshal.No_sharing ] in
  Char.code m.[20] = 0x08 && Char.code m.[23] land 3 <> 0

let to_string (v : 'a) (flags : Marshal.extern_flags list) : string =
  let m = Marshal.to_string v flags in
  if not colored then m else try clean m with Unknown | Invalid_argument _ | Not_found -> m
