(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: copied from libs/physics/2d/Contact.ml in the author's playground.
 * Where it has optional arguments, they are required here
 * (docs/plans/done/plan_playground.md). *)

(* See Contact.mli *)

type t = { normal : Vec2.t; depth : float; point : Vec2.t }
