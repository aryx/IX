(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mix.mli *)

(* ix: the author's playground's libs/audio/signal/Mix.ml; its optional arguments are said (docs/plans/plan_audio.md) *)

let add (sounds : Signal.t list) : Signal.t =
  let n = List.fold_left (fun m s -> max m (Array.length s)) 0 sounds in
  let out = Array.make n 0. in
  List.iter (fun s -> Array.iteri (fun i x -> out.(i) <- out.(i) +. x) s) sounds;
  out

let gain (g : float) (s : Signal.t) : Signal.t = Array.map (fun x -> g *. x) s
let delay (seconds : float) (s : Signal.t) : Signal.t = Array.append (Array.make (Signal.samples seconds) 0.) s
let then_ (a : Signal.t) (b : Signal.t) : Signal.t = Array.append a b
let decibels (ratio : float) : float = 20. *. log10 ratio
let of_decibels (db : float) : float = 10. ** (db /. 20.)
let clip (x : float) : float = Float.max (-1.) (Float.min 1. x)
let soft_clip (x : float) : float = tanh x
(* ix: soft was optional: false *)
let limit ~(soft : bool) (s : Signal.t) : Signal.t = Array.map (if soft then soft_clip else clip) s
