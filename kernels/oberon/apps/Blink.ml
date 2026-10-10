(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Blink.mli *)

let tick () = Display.copy_pattern White Display.block (Display.width - 12) 4 Invert
(* (every 50 turns of the loop: half a second when nothing happens) *)
let task = Oberon.new_task tick 50

let run () = Oberon.install task
let stop () = Oberon.remove task

let () = Modules.command "Blink.Run" run; Modules.command "Blink.Stop" stop
