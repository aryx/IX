(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

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

(* (the frame's words of 8 bytes, an AArch32 process's registers their
 * low halves: x0-x14, the pc ELR's 32, the psr SPSR's 33) *)
let low frame k = String.sub frame (8 * k) 4

let plan9 frame typ =
  String.concat "" (List.map (low frame) [ 0; 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14 ])
  ^ Machine.le32 typ ^ low frame 33 ^ low frame pc

let into_frame frame u =
  let b = Bytes.of_string frame in
  for k = 0 to 14 do
    Bytes.blit_string u (4 * k) b (8 * k) 4;
    Bytes.fill b ((8 * k) + 4) 4 '\000'
  done;
  Bytes.blit_string u 68 b (8 * pc) 4;
  Bytes.fill b ((8 * pc) + 4) 4 '\000';
  Bytes.to_string b
