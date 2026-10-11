(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Noise.mli *)

(* ix: the author's playground's libs/audio/synthesis/Noise.ml; its optional arguments are said (docs/plans/plan_audio.md) *)

type mode = Long | Short

let step (mode : mode) (r : int) : int =
  let tap = match mode with Long -> 1 | Short -> 6 in
  let feedback = (r land 1) lxor ((r lsr tap) land 1) in
  (r lsr 1) lor (feedback lsl 14)

let period (mode : mode) : int =
  let rec go n r = if r = 1 && n > 0 then n else go (n + 1) (step mode r) in
  go 0 1

(* ix: mode was optional: Long *)
let render ~(mode : mode) ~(rate : float) (seconds : float) : Signal.t =
  let r = ref 1 and clock = ref 0. in
  Array.init (Signal.samples seconds) (fun _ ->
      let out = if !r land 1 = 1 then 1. else -1. in
      (* rate / 44,100 steps per sample: a step each time the clock
       * passes a whole number *)
      clock := !clock +. (rate /. float_of_int Signal.rate);
      while !clock >= 1. do
        r := step mode !r;
        clock := !clock -. 1.
      done;
      out)

(* mod 2^32 by computing in 32 bits, which wrap by themselves, natively
 * and in a browser alike (where OCaml's ints are 32 bits anyway); the
 * state comes out signed, hence [uniform]'s correction *)
let lcg (x : int) : int = Int32.to_int (Int32.add (Int32.mul 1664525l (Int32.of_int x)) 1013904223l)

let uniform (x : int) : float =
  let x = float_of_int x in
  let x = if x < 0. then x +. 4294967296. else x in
  (2. *. x /. 4294967296.) -. 1.
