(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Out_channel.mli *)

type t = out_channel

let with_open openfile file f =
  let oc = openfile file in
  Fun.protect ~finally:(fun () -> close_out oc) (fun () -> f oc)

let with_open_bin file f = with_open open_out_bin file f
let with_open_gen flags perm file f = with_open (open_out_gen flags perm) file f

let output_string = Pervasives.output_string
