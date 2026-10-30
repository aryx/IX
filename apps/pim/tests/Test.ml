(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* the tests of mini-pim (docs/plans/plan_pim.md): its mail's, the
 * playground's libs/networking/tests of what was copied, the server's
 * and the connection's (Unit_smtp_server, Unit_imap); its store's
 * (Unit_items) *)

let () =
  Cap.main (fun caps ->
      Testo.interpret_argv ~project_name:"pim" (fun _env ->
          Unit_mail.tests @ Unit_mime.tests @ Unit_mail_thread.tests
          @ Unit_smtp.tests @ Unit_smtp_server.tests @ Unit_imap.tests
          @ Unit_compose.tests @ Unit_store.tests @ Unit_when.tests
          @ Unit_people.tests @ Unit_recur.tests @ Unit_ics.tests
          @ Unit_capture.tests
          @ Unit_items.tests (caps :> Unit_items.caps)))
