(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Exchange.mli *)

type block = {
  mutable owner : int;
  data : Bytes.t;
}
let in_message = -1
let freed = -2

let max_block = 1024 * 1024
let max_bytes = 4 * 1024 * 1024

let held = ref 0
let bytes () : int = !held

(* (the bytes are the kernel's heap's: its collector moves them, and
 * nobody else has their address) *)
let alloc (owner : int) (n : int) : block option =
  if n < 0 || n > max_block || !held + n > max_bytes then None
  else begin held := !held + n; Some { owner; data = Bytes.make n '\000' } end

let free (b : block) : unit =
  if b.owner <> freed then begin held := !held - Bytes.length b.data; b.owner <- freed end
