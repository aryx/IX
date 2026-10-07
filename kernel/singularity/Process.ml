(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Process.mli *)

(* the image's programs (cross.c): a pristine copy's physical address
 * and bytes, the physical address it is linked at; the bytes it may
 * take there, and those it takes with its bss *)
external count : unit -> int = "sip_count"
external image_base : int -> int = "sip_image_base"
external image_size : int -> int = "sip_image_size"
external image_addr : int -> int = "sip_image_addr"
external image_slot : int -> int = "sip_image_slot"
external image_extent : int -> int = "sip_image_extent"
(* into the code at a physical address; back when the process has ended *)
external enter : int -> unit = "sip_run"
external leave : unit -> unit = "sip_exit"

let status = ref 0

let run (i : int) : int =
  let addr = image_addr i in
  if image_extent i > image_slot i then
    Machine.panic (Printf.sprintf "program %d takes %d bytes, more than its slot" i (image_extent i));
  Machine.Phys.copy addr (image_base i) (image_size i);
  (* code was written: the Pi 4's flushes the instruction cache with
   * the user's table, which stays the empty one *)
  Machine.mmu_switch 0;
  status := 0;
  enter addr;
  !status

let exit (n : int) : unit = status := n; leave ()
