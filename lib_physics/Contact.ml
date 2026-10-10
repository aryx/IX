(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/physics/2d/Contact.ml; its optional arguments are said, where it has some (docs/plans/plan_playground.md) *)

(* See Contact.mli *)

type t = { normal : Vec2.t; depth : float; point : Vec2.t }
