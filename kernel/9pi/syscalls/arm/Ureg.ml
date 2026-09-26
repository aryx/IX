(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Ureg.mli: the Pi1's, the frame's words the registers *)

let r0 = 0
let sp = Arch.tf_sp
let pc = Arch.tf_pc
let get = Machine.tf_get
let set = Machine.tf_set

let regs () = String.sub (Machine.tf_bytes ()) 0 (17 * 4)

let set_regs s =
  let t = Machine.tf_bytes () in
  Machine.tf_set_bytes (s ^ String.sub t (16 * 4) (String.length t - (16 * 4)))
