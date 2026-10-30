(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-analyze: see Analyze.mli *)

let () = Cap.main (fun caps -> Logging.setup caps ~name:"mini-analyze"; CapStdlib.exit caps (Analyze.main caps (CapSys.argv caps)))
