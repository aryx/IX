(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's tests/css/Test.ml, its first version (docs/plans/plan_browser.md) *)

let () = Testo.interpret_argv ~project_name:"css" (fun _env -> Unit_css.tests @ Unit_css_syntax.tests @ Unit_selectors.tests @ Unit_cascade.tests)
