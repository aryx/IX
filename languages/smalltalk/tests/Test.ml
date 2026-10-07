(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

let () = Testo.interpret_argv ~project_name:"smalltalk" (fun _env -> Unit_smalltalk.tests @ Unit_squeak.tests @ Unit_colour.tests @ Unit_minimorphic.tests @ Unit_morphic.tests @ Unit_tools.tests @ Unit_etoys.tests)
