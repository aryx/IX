(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Out_channel.mli *)

type t = out_channel

(* (the channel is the descriptor: Stdlib.ml; mlsys.c's u_write writes
 * it all, or says -1) *)
external u_write : out_channel -> string -> int = "u_write"

let output_string oc s = if u_write oc s < 0 then failwith "cannot write"
