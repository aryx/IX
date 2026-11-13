(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: copied from libs/juice/Squash.ml in the author's playground *)

(* See Squash.mli *)

let keep_area (k : float) : float * float = (1. /. k, k)

(* the overshoot of out_elastic is the stretch *)
let landing ~(amount : float) (p : float) : float = Tween.lerp (1. -. amount) 1. (Ease.out Ease.elastic p)
