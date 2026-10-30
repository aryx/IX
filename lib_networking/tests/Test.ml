(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/networking/tests/Test.ml; the tests of what is here (docs/plans/plan_browser.md) *)

let () = Testo.interpret_argv ~project_name:"networking" (fun _env -> Unit_url.tests @ Unit_urlencoded.tests @ Unit_http.tests @ Unit_cookie.tests @ Unit_x509.tests @ Unit_tls13.tests @ Unit_mail.tests @ Unit_mail_thread.tests @ Unit_smtp.tests @ Unit_smtp_server.tests @ Unit_imap.tests @ Unit_mailto.tests)
