(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Files.mli *)

type t = FileDir.file

let old name = FileDir.find name
let new_ name : t = { name; data = Bytes.create 64; length = 0 }
let register (f : t) = FileDir.insert f
let length (f : t) = f.length

type rider = { file : t; mutable pos : int; mutable eof : bool }

let set (f : t) pos = { file = f; pos; eof = false }

let read_byte (r : rider) =
  if r.pos < r.file.length then begin
    let b = Char.code (Bytes.get r.file.data r.pos) in
    r.pos <- r.pos + 1;
    b
  end
  else (r.eof <- true; 0)

let read r = Char.chr (read_byte r)

let read_int r =
  let b0 = read_byte r in
  let b1 = read_byte r in
  let b2 = read_byte r in
  let b3 = read_byte r in
  b0 lor (b1 lsl 8) lor (b2 lsl 16) lor ((if b3 >= 128 then b3 - 256 else b3) lsl 24)

let read_string r =
  let b = Buffer.create 32 in
  let rec go () = let c = read_byte r in if c <> 0 && not r.eof then begin Buffer.add_char b (Char.chr c); go () end in
  go ();
  Buffer.contents b

(* at the rider, or the file's end when it is past it; the bytes' room doubled when full *)
let write_byte (r : rider) b =
  let f = r.file in
  if r.pos > f.length then r.pos <- f.length;
  if r.pos = Bytes.length f.data then begin
    let more = Bytes.create (2 * Bytes.length f.data) in
    Bytes.blit f.data 0 more 0 f.length;
    f.data <- more
  end;
  Bytes.set f.data r.pos (Char.chr (b land 255));
  r.pos <- r.pos + 1;
  if r.pos > f.length then f.length <- r.pos

let write r c = write_byte r (Char.code c)
let write_int r n = for k = 0 to 3 do write_byte r ((n asr (8 * k)) land 255) done
let write_string r s = String.iter (write r) s; write_byte r 0

let delete name = FileDir.delete name

let rename old_name new_name =
  match FileDir.find old_name with
  | None -> false
  | Some f ->
      FileDir.delete old_name;
      FileDir.insert { name = new_name; data = f.data; length = f.length };
      true
