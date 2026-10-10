(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Console.mli *)

let print (_ : < Cap.stdout; .. >) s = print_string s
let eprint (_ : < Cap.stderr; .. >) s = prerr_string s; flush stderr

let stdin (_ : < Cap.stdin; .. >) = stdin
let stdout (_ : < Cap.stdout; .. >) = stdout
let stderr (_ : < Cap.stderr; .. >) = stderr

let stdin_fd (_ : < Cap.stdin; .. >) = Unix.stdin
let stdout_fd (_ : < Cap.stdout; .. >) = Unix.stdout
