(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-mk, the ix build system: see CLI.mli *)

let () =
  Cap.main (fun caps -> Logging.setup caps ~name:"mini-mk"; CapStdlib.exit caps (CLI.main caps (CapSys.argv caps)))
