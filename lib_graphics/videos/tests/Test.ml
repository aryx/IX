(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

let () =
  Testo.interpret_argv ~project_name:"videos" (fun _env ->
      Unit_movie.tests @ Unit_yuv.tests @ Unit_psnr.tests @ Unit_y4m.tests @ Unit_fli.tests @ Unit_avi.tests @ Unit_mpeg1.tests
      @ Unit_mpeg_system.tests)
