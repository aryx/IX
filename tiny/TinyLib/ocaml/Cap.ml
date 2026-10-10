(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Cap.mli *)

type all_caps = < >

(* the capabilities are nothing: no value is read from them *)
let main f = f (Obj.magic ())
