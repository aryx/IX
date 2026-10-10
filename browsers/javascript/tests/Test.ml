(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's tests/js/Test.ml, its first version (docs/plans/plan_browser.md) *)

let () = Testo.interpret_argv ~project_name:"javascript" (fun _env -> Unit_js_lexer.tests @ Unit_js_parse.tests @ Unit_js_eval.tests @ Unit_js_es5.tests)
