(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

let () =
  Testo.interpret_argv ~project_name:"browser_webapi" (fun _env ->
      Unit_browser_script.tests @ Unit_script_dom.tests @ Unit_script_modules.tests @ Unit_xhr.tests @ Unit_cors.tests)
