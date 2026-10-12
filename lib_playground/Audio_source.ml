(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Audio_source.mli *)

type t = { pull : int -> float array * float array; latency : float -> unit }

let source : t option ref = ref None

let frame_samples = 44100 / 60
let queue_ahead = 3 * frame_samples

let s16 ((left, right) : float array * float array) : string =
  let n = Array.length left in
  let b = Bytes.create (4 * n) in
  (* old: a function [put at x] called twice a pair, with Bytes.set and
   * Char.chr: each a call that checks its argument, and a fifth of
   * TinyMissileCommand's instructions on mini-9pi (a profile at a
   * Pi 1's speed, 2026-10-13). The places are within [b] and the
   * bytes within 255 by what is written here. *)
  for i = 0 to (2 * n) - 1 do
    let x = if i land 1 = 0 then Array.unsafe_get left (i lsr 1) else Array.unsafe_get right (i lsr 1) in
    (* (to the nearest, a half away from zero: Float.round's) *)
    let y = x *. 32767. in
    let v = if y >= 0. then int_of_float (y +. 0.5) else - int_of_float (0.5 -. y) in
    let v = if v > 32767 then 32767 else if v < -32768 then -32768 else v in
    Bytes.unsafe_set b (2 * i) (Char.unsafe_chr (v land 0xff));
    Bytes.unsafe_set b ((2 * i) + 1) (Char.unsafe_chr ((v lsr 8) land 0xff))
  done;
  Bytes.to_string b

let wav (samples : string) : string =
  let n = String.length samples in
  let le (bytes : int) (v : int) : string = String.init bytes (fun i -> Char.chr ((v lsr (8 * i)) land 0xff)) in
  String.concat ""
    [ "RIFF"; le 4 (36 + n); "WAVEfmt "; le 4 16; le 2 1; le 2 2; le 4 44100; le 4 (4 * 44100); le 2 4; le 2 16; "data"; le 4 n; samples ]
