(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/juice/Tween.ml *)

(* See Tween.mli *)

let lerp (a : float) (b : float) (p : float) : float = a +. ((b -. a) *. p)

let progress ~(start : float) ~(duration : float) (now : float) : float =
  if duration <= 0. then 1. else Float.max 0. (Float.min 1. ((now -. start) /. duration))

let value (curve : Ease.t) (a : float) (b : float) ~(start : float) ~(duration : float) (now : float) : float =
  lerp a b (curve (progress ~start ~duration now))

let finished ~(start : float) ~(duration : float) (now : float) : bool = progress ~start ~duration now >= 1.
