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
  let put (at : int) (x : float) : unit =
    (* (to the nearest, a half away from zero: Float.round's) *)
    let y = x *. 32767. in
    let v = if y >= 0. then int_of_float (y +. 0.5) else - int_of_float (0.5 -. y) in
    let v = if v > 32767 then 32767 else if v < -32768 then -32768 else v in
    let v = v land 0xffff in
    Bytes.set b at (Char.chr (v land 0xff));
    Bytes.set b (at + 1) (Char.chr (v lsr 8)) in
  for i = 0 to n - 1 do
    put (4 * i) left.(i);
    put ((4 * i) + 2) right.(i)
  done;
  Bytes.to_string b

let wav (samples : string) : string =
  let n = String.length samples in
  let le (bytes : int) (v : int) : string = String.init bytes (fun i -> Char.chr ((v lsr (8 * i)) land 0xff)) in
  String.concat ""
    [ "RIFF"; le 4 (36 + n); "WAVEfmt "; le 4 16; le 2 1; le 2 2; le 4 44100; le 4 (4 * 44100); le 2 4; le 2 16; "data"; le 4 n; samples ]
