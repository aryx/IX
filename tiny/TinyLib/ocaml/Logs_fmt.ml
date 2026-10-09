(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Logs_fmt.mli *)

let reporter ~pp_header ~dst () : Logs.reporter = { pp_header; dst }
