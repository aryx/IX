(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Common.mli *)

(* as xix's Common *)
let ( ||| ) a b = match a with Some x -> x | None -> b
