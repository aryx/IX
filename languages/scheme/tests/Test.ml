(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

let () = Testo.interpret_argv ~project_name:"scheme" (fun _env -> Unit_scheme.tests @ Unit_scheme_step.tests @ Unit_scheme_secd.tests)
