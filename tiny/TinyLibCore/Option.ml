(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Option.mli *)

let get = function Some x -> x | None -> invalid_arg "option is None"
