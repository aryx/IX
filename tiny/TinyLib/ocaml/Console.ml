(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Console.mli *)

let print (_ : < Cap.stdout; .. >) s = print_string s
let eprint (_ : < Cap.stderr; .. >) s = prerr_string s; flush stderr

let stderr (_ : < Cap.stderr; .. >) = stderr

