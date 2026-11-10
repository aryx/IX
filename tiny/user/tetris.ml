(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* tetris, a program of TinyKernel.ml's: ../TinyAppTetris.ml, the game,
 * run by ../TinyLibPlayground.ml. *)
module TSys = TinyLibSystem
open TinyLibPlayground
open TinyAppTetris

let () = TSys.main "tetris" (fun caps _ -> run caps game)
