(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CapSys.mli. Each function writes the type of its capability, and
 * -caps checks it against what the function does (see lib_gate in
 * capabilities.dl). *)

let argv (_ : < Cap.argv; .. >) = Sys.argv
let set_signal (_ : < Cap.signal; .. >) = Sys.set_signal
let file_exists (_ : < Cap.readdir; .. >) = Sys.file_exists
let is_directory (_ : < Cap.readdir; .. >) = Sys.is_directory
let readdir (_ : < Cap.readdir; .. >) = Sys.readdir
let remove (_ : < Cap.open_out; .. >) = Sys.remove
let getenv (_ : < Cap.env; .. >) = Sys.getenv
let time (_ : < Cap.clock; .. >) = Sys.time
let getcwd (_ : < Cap.env; .. >) = Sys.getcwd
