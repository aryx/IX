(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Globals.mli *)

let editor : Efuns.editor = { edt_buffers = []; edt_map = Hashtbl.create 64; top_windows = [] }
