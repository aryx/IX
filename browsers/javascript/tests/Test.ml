(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's tests/js/Test.ml (its 8af888e) (docs/plans/plan_browser.md) *)

(* MINI_OPTI=off: the engine's simple code paths (Mini_opti), which
 * dune runs these same tests on a second time: the two agree *)
let mode = Sys.getenv_opt "MINI_OPTI"
let simple = mode = Some "off"
let () = if simple then Mini_opti.enabled := false

(* MINI_OPTI=walk: the optimized scopes, but a function's body walked
 * by the evaluator, not compiled (Js_compile): a third run *)
let () = if mode = Some "walk" then Mini_opti.compiled := false

(* a name of its own: the two runs keep their results apart *)
let () = Testo.interpret_argv ~project_name:(match mode with Some m -> "javascript-" ^ m | None -> "javascript") (fun _env -> Unit_js_lexer.tests @ Unit_js_utf16.tests @ Unit_js_parse.tests @ Unit_js_eval.tests @ Unit_js_scope.tests @ Unit_js_es5.tests @ Unit_js_classic.tests @ Unit_js_modern.tests @ Unit_js_promise.tests @ Unit_js_module.tests @ Unit_js_globals.tests)
