(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: copied from libs/physics/2d/Body.ml in the author's playground.
 * Where it has optional arguments, they are required here
 * (docs/plans/done/plan_playground.md). *)

(* See Body.mli *)

type t = { pos : Vec2.t; vel : Vec2.t; mass : float; spin : float; inertia : float }

(* ix: the four were optional: still, of mass 1, not spinning, never turning (infinity) *)
let make ~(vel : Vec2.t) ~(mass : float) ~(spin : float) ~(inertia : float) (pos : Vec2.t) : t =
  { pos; vel; mass; spin; inertia }

let point_velocity (b : t) (r : Vec2.t) : Vec2.t = Vec2.add b.vel (Vec2.scale b.spin (Vec2.perp r))
