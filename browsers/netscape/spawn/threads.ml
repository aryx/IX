(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Worker_spawn.mli: OCaml 4.14's threads, and mini-ml's *)

let parallel : bool = false
let spawn (f : unit -> unit) : unit = ignore (Thread.create f ())
