(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ptrace.mli: the mkfile's, mini-ml's, no ptrace (mini-acid on
 * Plan 9 reads /proc/$pid); later the runtime's primitives *)

let available = false
let none () = failwith "ptrace: not in this build (dune's mini-acid on Linux)"
let spawn (_ : < Cap.fork; Cap.exec; .. >) (_ : string) (_ : string array) : int = none ()
let getregs (_ : int) : string = none ()
let setregs (_ : int) (_ : string) : unit = none ()
let cont (_ : int) (_ : int) : unit = none ()
let wait (_ : int) : int = none ()
let signal (_ : < Cap.kill; .. >) (_ : int) (_ : int) : unit = none ()
