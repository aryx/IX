(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*   Pierre Weis and Xavier Leroy, projet Cristal, INRIA Rocquencourt  *)
(*                                                                     *)
(*  Copyright 1999 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)


(* Extensible buffers *)

type t =
 {mutable buffer : bytes;
  mutable position : int;
  mutable length : int;
  initial_buffer : bytes}

let create n =
 let n = if n < 1 then 1 else n in
 let n = if n > Sys.max_string_length then Sys.max_string_length else n in
 let s = Bytes.create n in
 {buffer = s; position = 0; length = n; initial_buffer = s}

let contents b = Bytes.sub_string b.buffer 0 b.position

let to_bytes b = Bytes.sub b.buffer 0 b.position

let sub b ofs len =
  if ofs < 0 || len < 0 || ofs > b.position - len
  then invalid_arg "Buffer.sub"
  else begin
    Bytes.sub_string b.buffer ofs len
  end
;;

let blit src srcoff dst dstoff len =
  if len < 0 || srcoff < 0 || srcoff > src.position - len
             || dstoff < 0 || dstoff > (Bytes.length dst) - len
  then invalid_arg "Buffer.blit"
  else
    Bytes.blit src.buffer srcoff dst dstoff len
;;

let nth b ofs =
  if ofs < 0 || ofs >= b.position then
   invalid_arg "Buffer.nth"
  else Bytes.get b.buffer ofs
;;

let length b = b.position

let clear b = b.position <- 0

let reset b =
  b.position <- 0; b.buffer <- b.initial_buffer;
  b.length <- Bytes.length b.buffer

let resize b more =
  let len = b.length in
  let new_len = ref len in
  while b.position + more > !new_len do new_len := 2 * !new_len done;
  if !new_len > Sys.max_string_length then begin
    if b.position + more <= Sys.max_string_length
    then new_len := Sys.max_string_length
    else failwith "Buffer.add: cannot grow buffer"
  end;
  let new_buffer = Bytes.create !new_len in
  Bytes.blit b.buffer 0 new_buffer 0 b.position;
  b.buffer <- new_buffer;
  b.length <- !new_len

let add_char b c =
  let pos = b.position in
  if pos >= b.length then resize b 1;
  (* (the place is there, by the line above: not checked again. A byte
   * set in place by mini-ml, where the checked one is a call of the
   * runtime; old: b.buffer.[pos] <- c) *)
  Bytes.unsafe_set b.buffer pos c;
  b.position <- pos + 1

let add_substring b s offset len =
  if offset < 0 || len < 0 || offset > String.length s - len
  then invalid_arg "Buffer.add_substring";
  let new_position = b.position + len in
  if new_position > b.length then resize b len;
  String.blit s offset b.buffer b.position len;
  b.position <- new_position

let add_subbytes b s offset len =
  add_substring b (Bytes.unsafe_to_string s) offset len

let add_string b s =
  let len = String.length s in
  let new_position = b.position + len in
  if new_position > b.length then resize b len;
  String.blit s 0 b.buffer b.position len;
  b.position <- new_position

let add_buffer b bs =
  add_subbytes b bs.buffer 0 bs.position

let add_channel b ic len =
  if len < 0 || len > Sys.max_string_length then   (* PR#5004 *)
    invalid_arg "Buffer.add_channel";
  if b.position + len > b.length then resize b len;
  really_input ic b.buffer b.position len;
  b.position <- b.position + len

let output_buffer oc b =
  output oc b.buffer 0 b.position

let add_bytes b s = add_string b (Bytes.unsafe_to_string s)

let truncate b len =
  if len < 0 || len > b.position then invalid_arg "Buffer.truncate"
  else b.position <- len

(* the binary fields, as Bytes' *)
let add_uint8 b n = add_char b (Char.unsafe_chr (n land 0xff))
let add_uint16_le b n = add_uint8 b n; add_uint8 b (n lsr 8)

let add_int32_le b n =
  add_uint16_le b (Int32.to_int n);
  add_uint16_le b (Int32.to_int (Int32.shift_right_logical n 16))

let add_int64_le b n =
  add_int32_le b (Int64.to_int32 n);
  add_int32_le b (Int64.to_int32 (Int64.shift_right_logical n 32))

let add_utf_8_uchar b u =
  let u = Uchar.to_int u in
  let tail k = add_uint8 b (0x80 lor ((u lsr (6 * k)) land 0x3F)) in
  if u < 0x80 then add_uint8 b u
  else if u < 0x800 then (add_uint8 b (0xC0 lor (u lsr 6)); tail 0)
  else if u < 0x10000 then (add_uint8 b (0xE0 lor (u lsr 12)); tail 1; tail 0)
  else (add_uint8 b (0xF0 lor (u lsr 18)); tail 2; tail 1; tail 0)
