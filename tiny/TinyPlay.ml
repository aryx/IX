(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyPlay.mli *)

open TinyCalls
open TinyLibPlayground

type wav = { rate : int; channels : int; bits : int; at : int; bytes : int }

(* numbers of 16 and 32 bits, the low byte first *)
let u16 s i = Char.code s.[i] + (256 * Char.code s.[i + 1])
let u32 s i = u16 s i + (65536 * u16 s (i + 2))

(* RIFF's chunks from 12 on, each four letters, a length and its bytes
 * (an odd length padded): "fmt " says the encoding (1, PCM), the
 * channels, the rate, the bits; "data" has the samples; the others
 * are skipped *)
let wav s =
  let n = String.length s in
  if n < 12 || String.sub s 0 4 <> "RIFF" || String.sub s 8 4 <> "WAVE" then failwith "not a WAV file";
  let rec chunks i w =
    if i + 8 > n then w
    else begin
      let size = u32 s (i + 4) in
      let id = String.sub s i 4 in
      let w =
        if id = "fmt " && i + 24 <= n then begin
          if u16 s (i + 8) <> 1 then failwith "not PCM";
          { w with channels = u16 s (i + 10); rate = u32 s (i + 12); bits = u16 s (i + 22) }
        end
        else if id = "data" then { w with at = i + 8; bytes = min size (n - i - 8) }
        else w in
      chunks (i + 8 + size + (size land 1)) w
    end in
  let w = chunks 12 { rate = 0; channels = 0; bits = 0; at = 0; bytes = 0 } in
  if w.rate = 0 || w.channels = 0 then failwith "no format";
  if w.bits <> 8 && w.bits <> 16 then failwith "not 8 or 16 bits";
  if w.rate > 96000 then failwith "more than 96,000 samples a second";
  w

(* the frames, and as many of the speaker's samples (the products
 * split, so that none passes 31 bits) *)
let frames w = w.bytes / (w.channels * w.bits / 8)
let samples w = let f = frames w in (f / w.rate * 8000) + (f mod w.rate * 8000 / w.rate)

(* At each sample, the frame at its time, k * rate / 8,000, exactly
 * and with no division a sample: the first one's computed, then each
 * next one is rate / 8,000 frames further and the remainder carried,
 * a frame more when it reaches 8,000 (Bresenham's line, of time
 * against frames). A channel's value is its top byte, signed (8 bits
 * are unsigned in a WAV, 128 the silence); the frame's, the mean of
 * two channels, the first of more. *)
let piece w s k n =
  let n = max 0 (min n (samples w - k)) in
  let size = w.bits / 8 in
  let frame = w.channels * size in
  let last = frames w - 1 in
  let channel o = if size = 1 then Char.code s.[o] - 128 else (let b = Char.code s.[o + 1] in if b > 127 then b - 256 else b) in
  let at = ref ((k / 8000 * w.rate) + (k mod 8000 * w.rate / 8000)) and left = ref (k mod 8000 * w.rate mod 8000) in
  let whole = w.rate / 8000 and part = w.rate mod 8000 in
  let b = Bytes.make n '\000' in
  for j = 0 to n - 1 do
    let o = w.at + (min last !at * frame) in
    let v = if w.channels = 1 then channel o else if w.channels = 2 then (channel o + channel (o + size)) asr 1 else channel o in
    Bytes.set b j (Char.chr (v land 255));
    at := !at + whole;
    left := !left + part;
    if !left >= 8000 then (left := !left - 8000; incr at)
  done;
  Bytes.to_string b

let block = 2048

let play out s =
  let w = wav s in
  let n = samples w in
  let rec from k = if k < n then (ignore (u_write out (samples_message (piece w s k block))); from (k + block)) in
  from 0
