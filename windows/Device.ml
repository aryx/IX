(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Device.mli *)

type t = [%mli]

let default = { name = ""; perm = 0o666; opened = (fun _ _ -> ()); read = (fun _ _ _ -> ""); write = (fun _ _ -> ()); closed = (fun _ -> ()) }

let part s offset count = if offset >= String.length s then "" else String.sub s offset (min count (String.length s - offset))

let later w message = raise (P9_server.Later (fun reply -> Window.send w (message reply)))
