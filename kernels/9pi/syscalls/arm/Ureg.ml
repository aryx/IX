(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ureg.mli: the Pi1's, the frame's words the registers *)

let r0 = 0
let sp = Arch.tf_sp
let pc = Arch.tf_pc
let get = Machine.tf_get
let set = Machine.tf_set

let regs () = String.sub (Machine.tf_bytes ()) 0 (17 * 4)

(* (the frame's words of 4 bytes: r0-r15, the pc r15, the psr 16) *)
let plan9 frame typ =
  String.sub frame 0 60 ^ Machine.le32 typ ^ String.sub frame 64 4 ^ String.sub frame 60 4

let into_frame frame u =
  String.sub u 0 60 ^ String.sub u 68 4 ^ String.sub frame 64 (String.length frame - 64)

let set_regs s =
  let t = Machine.tf_bytes () in
  Machine.tf_set_bytes (s ^ String.sub t (16 * 4) (String.length t - (16 * 4)))
