(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Svf.mli *)

(* ix: the author's playground's libs/audio/instruments/Svf.ml (docs/plans/plan_audio.md) *)

type model = Chamberlin | Zero_delay
type mode = Low_pass | Band_pass | High_pass | Notch

let modes = [ Low_pass; Band_pass; High_pass; Notch ]

(* the two integrators' memories: for Chamberlin's, the low-pass and
 * band-pass outputs; for the zero-delay one, the trapezoids' states *)
(* ix: in a flat array of two, s1 then s2, the filters' loop on flat
 * arrays: by mini-ml a mutable float field stored, or a float stored in
 * a float array, is a new block and the write barrier, each sample
 * (old: { mutable s1 : float; mutable s2 : float }, process on
 * Signal.t) *)
type t = Float.Array.t

let create () : t = Float.Array.make 2 0.
(* ix: Signal's at_most and at_least, inlined (old: Float.min 20000.
 * (Float.max 10. cutoff)) *)
let clamp (cutoff : float) : float =
  Signal.at_most 20000. (Signal.at_least 10. cutoff)

let pick (mode : mode) ~low ~band ~high : float =
  match mode with Low_pass -> low | Band_pass -> band | High_pass -> high | Notch -> low +. high

(* two integrators in a loop, each fed the last one's output of this
 * sample or the last: low += f band, high = x - low - band / q, band +=
 * f high *)
let chamberlin (t : t) (mode : mode) ~(cutoff : float) ~(q : float) (x : float) : float =
  let s1 = Float.Array.get t 0 and s2 = Float.Array.get t 1 in
  let f = 2. *. sin (Float.pi *. clamp cutoff /. float_of_int Signal.rate) in
  let low = s2 +. (f *. s1) in
  let high = x -. low -. (s1 /. q) in
  let band = s1 +. (f *. high) in
  Float.Array.set t 0 band;
  Float.Array.set t 1 low;
  pick mode ~low ~band ~high

(* the same loop solved: the high-pass first, from the two states, then
 * the two trapezoidal integrators; [g] the prewarped cutoff's *)
let solved (t : t) (mode : mode) ~(g : float) ~(q : float) (x : float) : float =
  let s1 = Float.Array.get t 0 and s2 = Float.Array.get t 1 in
  let r2 = 1. /. q in
  let high = (x -. ((r2 +. g) *. s1) -. s2) /. (1. +. (r2 *. g) +. (g *. g)) in
  let v1 = g *. high in
  let band = v1 +. s1 in
  Float.Array.set t 0 (band +. v1);
  let v2 = g *. band in
  let low = v2 +. s2 in
  Float.Array.set t 1 (low +. v2);
  pick mode ~low ~band ~high

let prewarped (cutoff : float) : float =
  tan (Float.pi *. clamp cutoff /. float_of_int Signal.rate)

let zero_delay (t : t) (mode : mode) ~(cutoff : float) ~(q : float)
    (x : float) : float =
  solved t mode ~g:(prewarped cutoff) ~q x

let process (t : t) (model : model) (mode : mode) ~(cutoff : Float.Array.t)
    ~(q : float) (samples : Float.Array.t) : unit =
  for i = 0 to Float.Array.length samples - 1 do
    let cutoff = Float.Array.get cutoff i in
    Float.Array.set samples i
      (match model with
      | Chamberlin -> chamberlin t mode ~cutoff ~q (Float.Array.get samples i)
      | Zero_delay -> zero_delay t mode ~cutoff ~q (Float.Array.get samples i))
  done

(* ix: a cutoff that does not move, its tan once (the drums' filters
 * were given an array of the same cutoff) *)
let process_fixed (t : t) (model : model) (mode : mode) ~(cutoff : float)
    ~(q : float) (samples : Float.Array.t) : unit =
  match model with
  | Chamberlin ->
      let cutoff = Float.Array.make (Float.Array.length samples) cutoff in
      process t model mode ~cutoff ~q samples
  | Zero_delay ->
      let g = prewarped cutoff in
      for i = 0 to Float.Array.length samples - 1 do
        Float.Array.set samples i
          (solved t mode ~g ~q (Float.Array.get samples i))
      done
