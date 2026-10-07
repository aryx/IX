(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: the author's playground's libs/physics/2d/Body.ml; its optional arguments are said, where it has some (docs/plans/plan_playground.md) *)

(* See Body.mli *)

type t = { pos : Vec2.t; vel : Vec2.t; mass : float; spin : float; inertia : float }

(* ix: the four were optional: still, of mass 1, not spinning, never turning (infinity) *)
let make ~(vel : Vec2.t) ~(mass : float) ~(spin : float) ~(inertia : float) (pos : Vec2.t) : t =
  { pos; vel; mass; spin; inertia }

let point_velocity (b : t) (r : Vec2.t) : Vec2.t = Vec2.add b.vel (Vec2.scale b.spin (Vec2.perp r))
