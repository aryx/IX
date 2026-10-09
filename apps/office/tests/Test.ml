(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)
(* ix: as the author's playground's appkits/tests/Test.ml and apps/office/tests/Test.ml, for what is here (docs/plans/plan_office.md) *)

let () =
  Testo.interpret_argv ~project_name:"office" (fun _env ->
      List.concat
        [ Unit_document.tests; Unit_rich.tests; Unit_page.tests; Unit_paint.tests; Unit_draw.tests; Unit_embed.tests; Unit_parts.tests ])
