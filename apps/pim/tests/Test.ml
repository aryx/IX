(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* the tests of mini-pim (docs/plans/plan_pim.md): so far its mail's,
 * the playground's libs/networking/tests of what was copied, and the
 * server's and the connection's (Unit_smtp_server) *)

let () =
  Testo.interpret_argv ~project_name:"pim" (fun _env ->
      Unit_mail.tests @ Unit_mime.tests @ Unit_mail_thread.tests
      @ Unit_smtp.tests @ Unit_smtp_server.tests @ Unit_imap.tests)
