(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Page.mli *)

type perm = Kernel_rw | User_ro | User_rw

type t = { pa : int; perm : perm }
