(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's tests/html/Test.ml, its first version (docs/plans/plan_browser.md) *)

let () = Testo.interpret_argv ~project_name:"html" (fun _env -> Unit_charset.tests @ Unit_entities.tests @ Unit_html_lexer.tests @ Unit_html_tree.tests @ Unit_line_mode.tests @ Unit_forms.tests)
