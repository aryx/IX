(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* the tests of mini-pim (docs/plans/plan_pim.md): so far its mail's
 * formats, the playground's libs/networking/tests of them *)

let () = Testo.interpret_argv ~project_name:"pim" (fun _env -> Unit_mail.tests @ Unit_mime.tests @ Unit_mail_thread.tests)
