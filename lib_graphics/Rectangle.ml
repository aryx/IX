(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* A rectangle of the screen: its top left corner, and the point just
 * past its bottom right one (Plan 9's Rectangle: max is not inside;
 * xix's lib_graphics/geometry). No Rectangle.mli: a type and its
 * arithmetic. *)

type t = { min : Point.t; max : Point.t }

let v x0 y0 x1 y1 = { min = Point.v x0 y0; max = Point.v x1 y1 }
let dx r = r.max.x - r.min.x
let dy r = r.max.y - r.min.y
(* moved by a point; shrunk by n on each side (grown, when negative) *)
let add r (p : Point.t) = { min = Point.add r.min p; max = Point.add r.max p }
let inset r n = v (r.min.x + n) (r.min.y + n) (r.max.x - n) (r.max.y - n)
let contains r (p : Point.t) = p.x >= r.min.x && p.x < r.max.x && p.y >= r.min.y && p.y < r.max.y
