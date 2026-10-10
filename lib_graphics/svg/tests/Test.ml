(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

let () = Testo.interpret_argv ~project_name:"svg" (fun _env -> Unit_svg.tests)
