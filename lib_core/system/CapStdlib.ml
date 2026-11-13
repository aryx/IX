(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CapStdlib.mli. Each function writes the type of its capability,
 * and -caps checks it against what the function does (see lib_gate in
 * capabilities.dl). *)

let exit (_ : < Cap.exit; .. >) = exit
let open_in (_ : < Cap.open_in; .. >) file = open_in file
