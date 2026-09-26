(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The arm program's registers in the kernel's trap frame. The
 * programs are principia's arm ones (5c's) on both boards; the kernel
 * is arm's on the Pi1 (its trap frame the program's r0-r14, pc, psr)
 * and arm64's on the Pi4, the program then run in AArch32 at EL0 (its
 * r0-r14 the frame's x0-x14, its pc ELR's, its CPSR SPSR's). *)

(* the frame's words of r0, sp (r13), the pc; their 32-bit values *)
val r0 : int
val sp : int
val pc : int
val get : int -> int
val set : int -> int -> unit

(* r0-r14, the pc, the psr: 17 words of 4 bytes (Plan 9 arm's order in
 * a Ureg, less its type); [set_regs] takes r0-r14 and the pc, the psr
 * kept *)
val regs : unit -> string
val set_regs : string -> unit
