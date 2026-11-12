(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* square, a program of TinyKernel.ml's: ../TinyAppSquare.ml's game run
 * by TinyLibPlayground, its program *)
let () =
  TinyLibSystem.main "square" (fun caps _ ->
      TinyLibPlayground.run caps TinyAppSquare.game)
