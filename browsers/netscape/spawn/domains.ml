(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Worker_spawn.mli: OCaml 5's domains *)

let parallel : bool = true
let spawn (f : unit -> unit) : unit = ignore (Domain.spawn f)
