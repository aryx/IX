(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's playground's libs/networking/tests/Test.ml; the tests of what is here (docs/plans/plan_browser.md) *)

let () = Testo.interpret_argv ~project_name:"networking" (fun _env -> Unit_url.tests @ Unit_urlencoded.tests @ Unit_http.tests @ Unit_x509.tests @ Unit_tls13.tests)
