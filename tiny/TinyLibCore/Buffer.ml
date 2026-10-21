(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Buffer.mli *)

type t = { mutable buffer_bytes : bytes; mutable buffer_length : int }

(* (at most 256 bytes at first: a program's partition is 1 MB, and
 * create's size is a guess, OCaml's too) *)
let create n =
  { buffer_bytes = Bytes.make (max 16 (min n 256)) '\000'; buffer_length = 0 }

(* room for more: the bytes copied into twice as many, or more *)
let grow b more =
  let need = b.buffer_length + more in
  let cap = Bytes.length b.buffer_bytes in
  if need > cap then begin
    let n = ref (2 * cap) in
    while !n < need do n := 2 * !n done;
    let bytes = Bytes.make !n '\000' in
    Bytes.blit b.buffer_bytes 0 bytes 0 b.buffer_length;
    b.buffer_bytes <- bytes
  end

let add_string b s =
  let n = String.length s in
  grow b n;
  Bytes.blit_string s 0 b.buffer_bytes b.buffer_length n;
  b.buffer_length <- b.buffer_length + n
let add_char b c =
  grow b 1;
  Bytes.set b.buffer_bytes b.buffer_length c;
  b.buffer_length <- b.buffer_length + 1
let contents b = Bytes.sub_string b.buffer_bytes 0 b.buffer_length
let length b = b.buffer_length
let clear b = b.buffer_length <- 0
