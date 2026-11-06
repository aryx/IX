(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CapStdlib.mli: the capability's type written, which -caps checks
 * against what the function does (capabilities.dl's lib_gate) *)

let exit (_ : < Cap.exit; .. >) = exit
let open_in (_ : < Cap.open_in; .. >) file = open_in file
