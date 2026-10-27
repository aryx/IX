(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Vco.mli *)

(* ix: the author's playground's libs/audio/instruments/Vco.ml its optional arguments are said (docs/plans/plan_audio.md) *)

type shape = Sine | Triangle | Sawtooth | Pulse

let shapes = [ Sine; Triangle; Sawtooth; Pulse ]
let name = function Sine -> "sine" | Triangle -> "triangle" | Sawtooth -> "sawtooth" | Pulse -> "pulse"

(* the phase; for a master, where in each step of the last block it
 * wrapped (the fraction of the step, or -1); for a slave, the second
 * half of a restart's correction, due at the next sample (h, d) *)
(* ix: wraps a flat array, the phase in a variable while a block is
 * filled, the samples in flat arrays: by mini-ml a float stored in a
 * float array or a mutable float field is a new block and the write
 * barrier, each sample (old: wraps : float array; run on Signal.t,
 * t.phase read and written each sample) *)
type t = {
  mutable phase : float;
  mutable wraps : Float.Array.t;
  mutable due : (float * float) option;
}

let create () : t = { phase = 0.; wraps = Float.Array.make 0 0.; due = None }

let naive (shape : shape) ~(width : float) (phase : float) : float =
  match shape with
  | Sine -> Oscillator.wave Sine phase
  | Triangle -> Oscillator.wave Triangle phase
  | Sawtooth -> Oscillator.wave Sawtooth phase
  | Pulse -> Oscillator.pulse ~width phase

let band_limited_wave (shape : shape) ~(width : float) ~(dt : float) (phase : float) : float =
  match shape with
  | Sine -> Oscillator.wave Sine phase
  | Triangle -> Oscillator.wave_band_limited Triangle ~dt phase
  | Sawtooth -> Oscillator.wave_band_limited Sawtooth ~dt phase
  | Pulse -> Oscillator.pulse_band_limited ~width ~dt phase

(* the correction of the wave's own jump at phase 0 (the sawtooth's
 * down, the pulse's up), to leave out where a restart replaced it *)
let own_jump (shape : shape) ~(dt : float) (phase : float) : float =
  match shape with
  | Sawtooth -> -.Oscillator.polyblep ~dt phase
  | Pulse -> Oscillator.polyblep ~dt phase
  | Sine | Triangle -> 0.

let wrap (x : float) : float = x -. Float.floor x

type restart = Fraction | At_sample

(* ix: run's band-limited pulse and sawtooth without a master (rebirth's
 * squares and bass lines), each sample in one loop: Oscillator's
 * pulse_band_limited, wave_band_limited and polyblep written in it,
 * the same operations in the same order; by mini-ml each of their
 * floats was a new block, five a sample (old: run's loop for all) *)
let run_plain (t : t) (shape : shape) ~(width : Float.Array.t option)
    ~(frequency : Float.Array.t) (out : Float.Array.t) : unit =
  let phase = ref t.phase in
  for i = 0 to Float.Array.length out - 1 do
    let dt = Float.Array.get frequency i /. float_of_int Signal.rate in
    let width =
      match width with
      | None -> 0.5
      | Some w ->
          Signal.at_most 0.99 (Signal.at_least 0.01 (Float.Array.get w i))
    in
    let p = !phase in
    (* polyblep ~dt p *)
    let at_p =
      if p < dt then (let u = p /. dt in (2. *. u) -. (u *. u) -. 1.)
      else if p > 1. -. dt then
        (let u = (p -. 1.) /. dt in (u *. u) +. (2. *. u) +. 1.)
      else 0.
    in
    let x =
      match shape with
      | Sawtooth -> ((2. *. p) -. 1.) -. at_p
      | _ ->
          (* polyblep ~dt (wrap (p -. width)) *)
          let q = wrap (p -. width) in
          let at_q =
            if q < dt then (let u = q /. dt in (2. *. u) -. (u *. u) -. 1.)
            else if q > 1. -. dt then
              (let u = (q -. 1.) /. dt in (u *. u) +. (2. *. u) +. 1.)
            else 0.
          in
          ((if p < width then 1. else -1.) -. ((2. *. width) -. 1.))
          +. at_p -. at_q
    in
    Float.Array.set t.wraps i
      (if p +. dt >= 1. then (1. -. p) /. dt else -1.);
    phase := wrap (p +. dt);
    Float.Array.set out i x
  done;
  t.phase <- !phase

(* ix: width and sync were optional; with band_limited one argument
 * here: mini-ml's arm takes seven parameters at most *)
let run ((band_limited, width, sync) : bool * Float.Array.t option * t option)
    ~(restart : restart) (t : t) (shape : shape) ~(frequency : Float.Array.t)
    (out : Float.Array.t) : unit =
  let n = Float.Array.length out in
  if Float.Array.length t.wraps <> n then t.wraps <- Float.Array.make n (-1.);
  match sync, t.due, shape with
  | None, None, (Pulse | Sawtooth) when band_limited ->
      run_plain t shape ~width ~frequency out
  | _ ->
  let phase = ref t.phase in
  for i = 0 to n - 1 do
    let dt = Float.Array.get frequency i /. float_of_int Signal.rate in
    (* (ix: Signal's clamps, inlined; old: Float.min 0.99 (Float.max
     * 0.01 w.(i))) *)
    let width =
      match width with
      | None -> 0.5
      | Some w ->
          Signal.at_most 0.99 (Signal.at_least 0.01 (Float.Array.get w i))
    in
    let p = !phase in
    let x = ref (if band_limited then band_limited_wave shape ~width ~dt p else naive shape ~width p) in
    (* the second half of the last step's restart *)
    (match t.due with
    | Some (h, d) ->
        x := !x +. (h /. 2. *. ((2. *. d) -. (d *. d) -. 1.)) -. own_jump shape ~dt p;
        t.due <- None
    | None -> ());
    (* restarted before the next sample? at [f], a fraction of the step *)
    let restart_at =
      match sync with
      | Some m when i < Float.Array.length m.wraps -> Float.Array.get m.wraps i
      | _ -> -1.
    in
    if restart_at >= 0. then (
      let f = match restart with Fraction -> restart_at | At_sample -> 1. in
      let d = 1. -. f in
      let before = naive shape ~width (wrap (p +. (f *. dt))) and after = naive shape ~width 0. in
      let h = after -. before in
      if band_limited then (
        (* its own jump, if it was coming in this step, won't: the
         * restart comes first *)
        if p +. (f *. dt) < 1. then x := !x -. own_jump shape ~dt p;
        x := !x +. (h /. 2. *. d *. d);
        t.due <- Some (h, d));
      Float.Array.set t.wraps i f;
      phase := d *. dt)
    else (
      Float.Array.set t.wraps i
        (if p +. dt >= 1. then (1. -. p) /. dt else -1.);
      phase := wrap (p +. dt));
    Float.Array.set out i !x
  done;
  t.phase <- !phase

(* ix: band_limited (true), width and sync were optional *)
let fill ~(band_limited : bool) ~(width : Float.Array.t option)
    ~(sync : t option) (t : t) (shape : shape) ~(frequency : Float.Array.t)
    (out : Float.Array.t) : unit =
  run (band_limited, width, sync) ~restart:Fraction t shape ~frequency out

let fill_sync_at_sample ~(width : Float.Array.t option) ~(sync : t) (t : t)
    (shape : shape) ~(frequency : Float.Array.t) (out : Float.Array.t) : unit =
  run (true, width, Some sync) ~restart:At_sample t shape ~frequency out
