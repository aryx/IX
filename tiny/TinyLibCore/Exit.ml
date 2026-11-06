(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Exit.mli *)

type code = int

type t =
  | OK
  | Err of string
  | Code of code

exception ExitCode of code
