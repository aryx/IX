(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Common.mli *)

let ( ||| ) o default = match o with Some x -> x | None -> default
