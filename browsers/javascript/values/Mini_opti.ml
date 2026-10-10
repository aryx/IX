(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's libs/opti/Mini_opti.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* See Mini_opti.mli *)

let enabled = ref true
let compiled = ref true

type letters = Segments | Pictures

let letters = ref Pictures
