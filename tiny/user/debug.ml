(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* debug, a program of TinyKernel.ml's: ../TinyDebugger.ml. *)

let () = TinyLibSystem.main "debug" (fun caps _ -> TinyDebugger.main caps; Exit.OK)
