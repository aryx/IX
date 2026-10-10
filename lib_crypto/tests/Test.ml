(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's playground's libs/crypto/tests/Test.ml (docs/plans/plan_browser.md) *)

let () = Testo.interpret_argv ~project_name:"crypto" (fun _env -> Unit_sha2.tests @ Unit_hmac.tests @ Unit_ciphers.tests @ Unit_public_key.tests)
