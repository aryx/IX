(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Pitch_effect.mli *)

(* ix: the author's playground's libs/audio/Pitch_effect.ml (docs/plans/plan_audio.md) *)

type t =
  | Vibrato of { rate : float; depth : float }
  | Jump of { semitones : float; at : float }
  | Arpeggio of { semitones : float list; step : float }

let semitones (k : float) : float = 2. ** (k /. 12.)

let factor (p : t) (t : float) : float =
  match p with
  | Vibrato { rate; depth } -> semitones (depth *. sin (2. *. Float.pi *. rate *. t))
  | Jump { semitones = k; at } -> if t < at then 1. else semitones k
  | Arpeggio { semitones = []; _ } -> 1.
  | Arpeggio { semitones = l; step } -> semitones (List.nth l (int_of_float (t /. step) mod List.length l))
