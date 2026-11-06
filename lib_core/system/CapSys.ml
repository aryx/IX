(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See CapSys.mli *)

let argv _caps = Sys.argv
let set_signal _caps = Sys.set_signal
let file_exists _caps = Sys.file_exists
let is_directory _caps = Sys.is_directory
let readdir _caps = Sys.readdir
let remove _caps = Sys.remove
let getenv _caps = Sys.getenv
let time _caps = Sys.time
let getcwd _caps = Sys.getcwd
