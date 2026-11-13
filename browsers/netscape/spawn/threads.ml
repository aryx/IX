(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Worker_spawn.mli: OCaml 4.14's threads (mini-ml's version is
 * large_threads.ml) *)

let parallel : bool = false
let spawn (f : unit -> unit) : unit = ignore (Thread.create f ())
