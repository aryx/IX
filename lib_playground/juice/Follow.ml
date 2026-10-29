(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/juice/Follow.ml; its optional arguments are said *)

(* See Follow.mli *)

type t = { value : float; velocity : float }

let at (x : float) : t = { value = x; velocity = 0. }

(* the velocity first, then the value with the new velocity *)
(* ix: the two were optional: 2 a second, and 1 (no overshoot) *)
let chase ~(frequency : float) ~(damping : float) ~(dt : float) (target : float) (t : t) : t =
  let w = 2. *. Float.pi *. frequency in
  let acceleration = (w *. w *. (target -. t.value)) -. (2. *. damping *. w *. t.velocity) in
  let velocity = t.velocity +. (acceleration *. dt) in
  { value = t.value +. (velocity *. dt); velocity }

let smooth ~(rate : float) ~(dt : float) (target : float) (x : float) : float = x +. ((target -. x) *. (1. -. exp (-.rate *. dt)))
