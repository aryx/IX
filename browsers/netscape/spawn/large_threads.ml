(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Worker_spawn.mli. This is the version for mini-ml's threads,
 * whose worker has the program's stacks (Thread.create_large), because
 * a page is laid out on it, deep recursions and all. *)

let parallel : bool = false
let spawn (f : unit -> unit) : unit = ignore (Thread.create_large f ())
