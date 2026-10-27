(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Modal.mli *)

(* ix: the author's playground's libs/audio/instruments/Modal.ml (docs/plans/plan_audio.md) *)

let rate = float_of_int Signal.rate

(* ix: w, r, a1 (2 r cos w), a2 (r^2), y1, y2, the next strike's
 * impulse, the amplitude's bound (decayed each sample), in a flat
 * array: by mini-ml a mutable float field stored is a new block and
 * the write barrier, four each sample (old: a record of them, mutable
 * but w) *)
type t = Float.Array.t

let w = 0 and r = 1 and a1 = 2 and a2 = 3
let y1 = 4 and y2 = 5 and pending = 6 and level_ = 7

let coefficients (t : t) (t60 : float) : unit =
  Float.Array.set t r (Float.pow 10. (-3. /. (Float.max 1e-4 t60 *. rate)));
  Float.Array.set t a1 (2. *. Float.Array.get t r *. cos (Float.Array.get t w));
  Float.Array.set t a2 (Float.Array.get t r *. Float.Array.get t r)

let create ~(frequency : float) ~(t60 : float) : t =
  let t = Float.Array.make 8 0. in
  Float.Array.set t w
    (2. *. Float.pi *. Float.min frequency (0.49 *. rate) /. rate);
  coefficients t t60;
  t

let strike (t : t) (a : float) : unit =
  Float.Array.set t pending
    (Float.Array.get t pending +. (a *. sin (Float.Array.get t w)));
  Float.Array.set t level_ (Float.Array.get t level_ +. Float.abs a)

let damp (t : t) ~(t60 : float) : unit = coefficients t t60

let next (t : t) : float =
  let y =
    (Float.Array.get t a1 *. Float.Array.get t y1)
    -. (Float.Array.get t a2 *. Float.Array.get t y2)
    +. Float.Array.get t pending
  in
  Float.Array.set t pending 0.;
  Float.Array.set t y2 (Float.Array.get t y1);
  Float.Array.set t y1 y;
  Float.Array.set t level_ (Float.Array.get t level_ *. Float.Array.get t r);
  y

let level (t : t) : float = Float.Array.get t level_
