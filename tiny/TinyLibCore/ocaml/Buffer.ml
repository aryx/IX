(* Pierre Weis and Xavier Leroy, projet Cristal, INRIA Rocquencourt
 * Objective Caml. Copyright 1999 INRIA. GNU Library General Public License, with the linking exception of OCaml's LICENSE. *)

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

let nth b ofs =
  if ofs < 0 || ofs >= b.position then
   invalid_arg "Buffer.nth"
  else Bytes.get b.buffer ofs
;;

let length b = b.position

let clear b = b.position <- 0

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

let add_bytes b s = add_string b (Bytes.unsafe_to_string s)

(* the binary fields, as Bytes' *)
let add_uint8 b n = add_char b (Char.unsafe_chr (n land 0xff))
let add_uint16_le b n = add_uint8 b n; add_uint8 b (n lsr 8)

let add_int32_le b n =
  add_uint16_le b (Int32.to_int n);
  add_uint16_le b (Int32.to_int (Int32.shift_right_logical n 16))

let add_int64_le b n =
  add_int32_le b (Int64.to_int32 n);
  add_int32_le b (Int64.to_int32 (Int64.shift_right_logical n 32))
