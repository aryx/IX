(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/ai/tests/Test.ml; the tests of the
 * modules copied *)

let () =
  Testo.interpret_argv ~project_name:"ai" (fun _env ->
      Unit_pathfind.tests @ Unit_ai.tests)
