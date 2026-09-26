(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* See Ureg.mli: the Pi4's, x0-x14, ELR (32), SPSR (33), their low 32
 * bits (the upper ones of an AArch32 process's x0-x14 are not its) *)

let r0 = 0
let sp = 13
let pc = Arch.tf_pc
let get i = Machine.tf_get i land 0xffffffff
let set = Machine.tf_set

let regs () =
  String.concat "" (List.map (fun i -> Machine.le32 (get i)) [ 0; 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14; pc; 33 ])

let set_regs s =
  for i = 0 to 14 do set i (Machine.get_le32 s (4 * i) land 0xffffffff) done;
  set pc (Machine.get_le32 s (4 * 15) land 0xffffffff)
