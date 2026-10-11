(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Signal.mli *)

(* ix: the author's playground's libs/audio/signal/Signal.ml; no Array.map2 (docs/plans/plan_audio.md) *)

type t = float array
type stereo = { left : t; right : t }

(* the same array twice: nothing here writes into a sound once made *)
let both (s : t) : stereo = { left = s; right = s }
let mono (s : stereo) : t = Array.mapi (fun i l -> (l +. s.right.(i)) /. 2.) s.left

let rate = 44100
let nyquist = float_of_int rate /. 2.
let samples (seconds : float) : int = int_of_float (seconds *. float_of_int rate)
let period_in_samples (frequency : float) : float = float_of_int rate /. frequency

let alias (frequency : float) : float =
  (* the spectrum repeats every [rate], and mirrors around each
   * multiple of it *)
  let f = Float.rem (Float.abs frequency) (float_of_int rate) in
  if f <= nyquist then f else float_of_int rate -. f

let of_function (seconds : float) (f : float -> float) : t =
  Array.init (samples seconds) (fun i -> f (float_of_int i /. float_of_int rate))

(* compared as ints; it was
 *
 *   max (-32768) (min 32767 (int_of_float (Float.round (x *. 32767.))))
 *
 * Stdlib's min and max are polymorphic, the runtime's generic compare
 * twice per sample written (notes_opti_ocaml.md) *)
let to_int16 (x : float) : int =
  let v = int_of_float (Float.round (x *. 32767.)) in
  if v < -32768 then -32768 else if v > 32767 then 32767 else v
