(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's tests/layout/Test.ml, its first version (docs/plans/plan_browser.md) *)

let () = Testo.interpret_argv ~project_name:"browser_layout" (fun _env -> Unit_html_layout.tests @ Unit_table_layout.tests @ Unit_box_layout.tests @ Unit_flex_layout.tests @ Unit_hit.tests)
