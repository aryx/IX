(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Char.mli *)

external code : char -> int = "%identity"
external chr : int -> char = "%identity"
