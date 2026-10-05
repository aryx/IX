(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* A point of the screen: x to the right, y down, in pixels (Plan 9's
 * Point; xix's lib_graphics/geometry). No Point.mli: a type and its
 * arithmetic. *)

type t = { x : int; y : int }

let zero = { x = 0; y = 0 }
let v x y = { x; y }
let add a b = { x = a.x + b.x; y = a.y + b.y }
let sub a b = { x = a.x - b.x; y = a.y - b.y }
