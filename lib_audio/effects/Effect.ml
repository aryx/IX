(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Effect.mli *)

(* ix: the author's playground's libs/audio/effects/Effect.ml (docs/plans/plan_audio.md) *)

type knob = { name : string; control : Control.t; initial : float }
type t = {
  name : string;
  knobs : knob list;
  set : string -> float -> unit;
  process : Signal.stereo -> unit;
  meters : unit -> (string * float) list;
}

let ramp (last : float) (now : float) (i : int) (n : int) : float = last +. ((now -. last) *. float_of_int (i + 1) /. float_of_int n)
