(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Drive.mli *)

(* ix: the author's playground's libs/audio/effects/Drive.ml (docs/plans/plan_audio.md) *)

type shape = Hard | Tanh | Cubic | Asymmetric

let shapes = [ Hard; Tanh; Cubic; Asymmetric ]
let name = function Hard -> "hard" | Tanh -> "tanh" | Cubic -> "cubic" | Asymmetric -> "asymmetric"
let bias = 0.3

let curve (shape : shape) (x : float) : float =
  match shape with
  | Hard -> Float.max (-1.) (Float.min 1. x)
  | Tanh -> tanh x
  | Cubic ->
      let x = Float.max (-1.) (Float.min 1. x) in
      1.5 *. (x -. (x *. x *. x /. 3.))
  | Asymmetric -> tanh (x +. bias) -. tanh bias

(* an 8th-order Butterworth low-pass: four biquads, the Qs of its poles'
 * pairs *)
let butterworth_qs = [| 0.50980; 0.60134; 0.89998; 2.56292 |]
let cutoff = 18000.

type t = {
  oversampling : int;
  filter : Filter.biquad array; (* the four stages, at L x the rate *)
  up : Filter.memory array;
  down : Filter.memory array;
  mutable dc : float; (* the high-pass's low-pass, taken away *)
  (* the last block's knobs, ramped from (nan: none yet) *)
  mutable last_drive : float;
  mutable last_mix : float;
}

let create ~(oversampling : int) () : t =
  let rate = float_of_int (oversampling * Signal.rate) in
  {
    oversampling;
    filter = Array.map (fun q -> Filter.biquad_at ~rate Filter.Low_pass ~cutoff ~q) butterworth_qs;
    up = Array.init 4 (fun _ -> Filter.silence ());
    down = Array.init 4 (fun _ -> Filter.silence ());
    dc = 0.;
    last_drive = nan;
    last_mix = nan;
  }

(* ix: Filter.chain, the four steps in one function (old: a loop of
 * Filter.step, each step's float a new block by mini-ml) *)
let chain (t : t) (memories : Filter.memory array) (x : float) : float =
  Filter.chain t.filter memories x

let dc_coefficient = Filter.one_pole_coefficient 10.

let process (t : t) (shape : shape) ~(drive : float) ~(mix : float) (s : Signal.t) : unit =
  let l = t.oversampling and n = Array.length s in
  let from_drive = if Float.is_nan t.last_drive then drive else t.last_drive
  and from_mix = if Float.is_nan t.last_mix then mix else t.last_mix in
  (* ix: a loop, the high-pass's state in a variable while the block is
   * made, the gain once when the drive stays (the ramp from a value to
   * itself is that value): by mini-ml a mutable float field stored is a
   * new block and the write barrier, and of_decibels a pow each sample
   * (old: Array.iteri, t.dc written each sample) *)
  let steady = from_drive = drive and g0 = Mix.of_decibels drive in
  let dc = ref t.dc in
  for i = 0 to n - 1 do
    let x = s.(i) in
    (* the knobs ramped over the block, the drive in dB *)
    let g =
      if steady then g0 else Mix.of_decibels (Effect.ramp from_drive drive i n)
    and mix = Effect.ramp from_mix mix i n in
    let wet =
      if l = 1 then curve shape (g *. x)
      else begin
        (* the sample, then L - 1 zeros, each through the chain; the
         * zeros make the level L times smaller, hence the L *)
        let out = ref 0. in
        for k = 0 to l - 1 do
          let up = chain t t.up (if k = 0 then float_of_int l *. x else 0.) in
          let y = chain t t.down (curve shape (g *. up)) in
          if k = 0 then out := y
        done;
        !out
      end
    in
    dc := !dc +. (dc_coefficient *. (wet -. !dc));
    s.(i) <- ((1. -. mix) *. x) +. (mix *. (wet -. !dc))
  done;
  t.dc <- !dc;
  t.last_drive <- drive;
  t.last_mix <- mix

let knobs : Effect.knob list =
  [
    { name = "shape"; control = Selector (List.map name shapes); initial = 1. };
    { name = "gain"; control = Knob (0., 36.); initial = 12. };
    { name = "oversampling"; control = Switch; initial = 1. };
  ]

let fx () : Effect.t =
  (* a drive per channel and per oversampling, each keeping its filters'
   * state while the other is used *)
  let plain = (create ~oversampling:1 (), create ~oversampling:1 ()) and oversampled = (create ~oversampling:4 (), create ~oversampling:4 ()) in
  let shape = ref Tanh and gain = ref 0. and x4 = ref false in
  let set (knob : string) (x : float) =
    match knob with
    | "shape" -> shape := List.nth shapes (max 0 (min (List.length shapes - 1) (Control.index x)))
    | "gain" -> gain := x
    | "oversampling" -> x4 := Control.on x
    | _ -> ()
  in
  List.iter (fun (k : Effect.knob) -> set k.name k.initial) knobs;
  let process (s : Signal.stereo) =
    let left, right = if !x4 then oversampled else plain in
    process left !shape ~drive:!gain ~mix:1. s.left;
    process right !shape ~drive:!gain ~mix:1. s.right
  in
  { name = "drive"; knobs; set; process; meters = (fun () -> []) }
