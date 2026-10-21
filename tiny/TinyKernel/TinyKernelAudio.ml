(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyKernelAudio.mli *)

(* OCaml builds this file too, on the host, where its sounds are tested
 * without a machine (tests/TinyKernelAudio_tests/Host.ml) *)

open TinyMemory

let per_ms = 8

(* Fixed point, and no division in a sample (tiny-machine divides by a
 * routine, a hundred instructions): the phase is in 65,536ths of a
 * period, to which a sample adds its step; the step is in 256ths of
 * those (a Hz is 8.192 of them a sample), so that a slide moves it a
 * little at each sample; the amplitude is in 65,536ths, and its first
 * 16 samples rise from nothing (2 ms: a sound that starts at its full
 * volume clicks). A noise is a random value at each period, by a
 * congruential generator. *)
let mix ring size at wave hz to_hz n volume =
  let n = max 1 n in
  let step0 = hz * 8192 / 1000 * 256 in
  let dstep = ((to_hz * 8192 / 1000 * 256) - step0) / n in
  let damp = volume * 65536 / n in
  let phase = ref 0 and step = ref step0 and amp = ref (volume * 65536)
  and noise = ref 1 in
  for i = 0 to n - 1 do
    let v = if i < 16 then ((!amp lsr 16) * i) lsr 4 else !amp lsr 16 in
    let q = !phase land 0xffff in
    let x =
      if wave = 0 then (if q < 32768 then v else - v)
      else if wave = 1 then (
        let t = (q * 4 * v) lsr 16 in
        if t < 2 * v then t - v else (3 * v) - t)
      else if wave = 2 then ((q * 2 * v) lsr 16) - v
      else ((((!noise lsr 16) land 255) * 2 * v) lsr 8) - v in
    let r = ring + ((at + i) land (size - 1)) in
    let b = peekb r in
    let y = (if b > 127 then b - 256 else b) + x in
    pokeb r ((if y > 127 then 127 else if y < -128 then -128 else y) land 255);
    let next = (!phase + (!step lsr 8)) land 0xffffff in
    if next lsr 16 <> !phase lsr 16 then
      noise := ((!noise * 69069) + 1) land 0xffffff;
    phase := next;
    step := !step + dstep;
    amp := !amp - damp
  done

(* a sound of a message: a tone (a wave, a pitch from and to, its
 * samples, a volume), or samples *)
type sound = Tone of int * int * int * int * int | Samples of string

let sound_length snd =
  match snd with Tone (_, _, _, n, _) -> n | Samples s -> String.length s

(* samples added to the ring as a tone's are *)
let add_samples ring size at s =
  for i = 0 to String.length s - 1 do
    let r = ring + ((at + i) land (size - 1)) in
    let b = peekb r and x = Char.code s.[i] in
    let y = (if b > 127 then b - 256 else b) + (if x > 127 then x - 256 else x) in
    pokeb r ((if y > 127 then 127 else if y < -128 then -128 else y) land 255)
  done

let mix_sound ring size at snd =
  match snd with
  | Tone (wave, hz, to_hz, n, volume) -> mix ring size at wave hz to_hz n volume
  | Samples s -> add_samples ring size at s

exception Bad_sound

(* a tone's message is 11 bytes: s, then five numbers of 16 bits, the
 * low byte first (TinyLibDraw's); samples' is p, their number, then
 * them *)
let sounds s =
  let num i = Char.code s.[i] + (256 * Char.code s.[i + 1]) in
  let rec from i =
    if i = String.length s then []
    else if i + 3 <= String.length s && s.[i] = 'p'
            && i + 3 + num (i + 1) <= String.length s then
      Samples (String.sub s (i + 3) (num (i + 1))) :: from (i + 3 + num (i + 1))
    else if i + 11 > String.length s || s.[i] <> 's' then raise Bad_sound
    else begin
      let wave = num (i + 1) and hz = num (i + 3) and to_hz = num (i + 5)
      and ms = num (i + 7) and volume = num (i + 9) in
      if wave > 3 || hz > 4000 || to_hz > 4000 || ms > 1000 || volume > 127 then
        raise Bad_sound;

      Tone (wave, hz, to_hz, ms * per_ms, volume) :: from (i + 11)
    end in
  from 0
