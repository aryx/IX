(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Square.ml on tiny-kernel, by tiny-ml (after it, as one program):
 * the game run. *)
open TinyLibPlayground
open Square

let () = TinyLibSystem.main "square" (fun caps _ -> run caps game)
