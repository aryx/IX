(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Fm.mli *)

(* ix: the author's playground's libs/audio/synthesis/Fm.ml (docs/plans/plan_audio.md) *)

let wave ~(index : float) (carrier : float) (modulator : float) : float =
  sin ((2. *. Float.pi *. carrier) +. (index *. sin (2. *. Float.pi *. modulator)))

let render ~(carrier : float) ~(ratio : float) ~(index : float) (seconds : float) : Signal.t =
  let rate = float_of_int Signal.rate in
  Array.init (Signal.samples seconds) (fun i ->
      let t = float_of_int i /. rate in
      let phase f = let p = f *. t in p -. Float.floor p in
      wave ~index (phase carrier) (phase (carrier *. ratio)))
