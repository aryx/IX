(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-awk, Plan 9's awk: see CLI.mli *)

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> CLI.main caps (CapSys.argv caps))))
