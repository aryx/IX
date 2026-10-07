(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Sip.mli *)

type process = int

external yield : unit -> unit = "sip_yield"
external abi_create : string -> int = "sip_create"
external abi_start : int -> int = "sip_start"
external join : int -> int = "sip_join"

let create (name : string) : process option =
  let h = abi_create name in
  if h < 0 then None else Some h

let start (p : process) : unit = ignore (abi_start p)
