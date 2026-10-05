(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Out_channel.mli *)

type t = out_channel

let with_open openfile file f =
  let oc = openfile file in
  Fun.protect ~finally:(fun () -> close_out oc) (fun () -> f oc)

let with_open_bin file f = with_open open_out_bin file f
let with_open_gen flags perm file f = with_open (open_out_gen flags perm) file f

let output_string = Pervasives.output_string
