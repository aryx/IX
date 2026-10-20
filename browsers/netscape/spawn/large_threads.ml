(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Worker_spawn.mli: mini-ml's threads, the worker with the
 * program's stacks (Thread.create_large: a page laid out on it, deep
 * recursions and all) *)

let parallel : bool = false
let spawn (f : unit -> unit) : unit = ignore (Thread.create_large f ())
