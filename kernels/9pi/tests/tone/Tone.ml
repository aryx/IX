(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Half a second of sound for /dev/audio (plan_audio.md, stage 3;
 * ../../Makefile's check-audio): tone > /dev/audio. Two triangle
 * waves, 441 Hz in the left ear and 882 Hz in the right one, so that
 * a listener (and tests/audio.py, on mini-qemu's WAV) tells the ears
 * apart; in integers, the same samples on any machine. 16 bits, the
 * low byte first, left then right, 44,100 pairs a second: what the
 * device takes. *)

let pairs = 22050
let loud = 12000

(* a triangle of [period] samples, from -loud to loud and back *)
let triangle i period =
  let half = period / 2 in
  let p = i mod period in
  (((if p < half then p else period - p) * 2 * loud) / half) - loud

let () =
  let b = Buffer.create (4 * pairs) in
  let add v =
    let v = v land 0xffff in
    Buffer.add_char b (Char.chr (v land 0xff));
    Buffer.add_char b (Char.chr (v lsr 8)) in
  for i = 0 to pairs - 1 do
    add (triangle i 100);
    add (triangle i 50)
  done;
  print_string (Buffer.contents b)
