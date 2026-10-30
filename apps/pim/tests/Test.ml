(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* the tests of mini-pim (docs/plans/done/plan_pim.md): its mail's
 * (the protocols' are lib_networking/tests'), its store's (Unit_items) *)

let () =
  Cap.main (fun caps ->
      Testo.interpret_argv ~project_name:"pim" (fun _env ->
          Unit_mime.tests @ Unit_compose.tests @ Unit_store.tests @ Unit_when.tests
          @ Unit_people.tests @ Unit_recur.tests @ Unit_ics.tests
          @ Unit_capture.tests @ Unit_money.tests
          @ Unit_books.tests @ Unit_zone.tests @ Unit_remind.tests
          @ Unit_detect.tests @ Unit_google.tests @ Unit_today.tests
          @ Unit_screen.tests @ Unit_envelopes.tests
          @ Unit_items.tests (caps :> Unit_items.caps)))
