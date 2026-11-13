(* The arm program's registers, in the kernel's trap frame. The programs
 * are principia's arm ones (made by 5c) on both boards. On the Pi1 the
 * kernel is arm's, and its trap frame holds the program's r0-r14, pc
 * and psr. On the Pi4 the kernel is arm64's, and the program runs in
 * AArch32 at EL0: its r0-r14 are the frame's x0-x14, its pc is ELR,
 * and its CPSR is SPSR. *)

(* the indexes of the frame's words for r0, sp (r13) and the pc; [get]
 * and [set] read and write their 32-bit values *)
val r0 : int
val sp : int
val pc : int
val get : int -> int
val set : int -> int -> unit

(* [regs ()] returns r0-r14, the pc and the psr, 17 words of 4 bytes
 * (Plan 9 arm's order in a Ureg, without its type). [set_regs] takes
 * r0-r14 and the pc, and keeps the psr. *)
val regs : unit -> string
val set_regs : string -> unit

(* [plan9 frame typ] returns a trap frame's bytes (a stopped process's,
 * from Machine.tf_slot_bytes) as Plan 9 arm's Ureg, 18 words: r0-r14,
 * the trap's type, the psr and the pc (this is /proc/n/regs, what acid
 * reads). [into_frame frame ureg] returns the frame with the Ureg's
 * r0-r14 and pc, and keeps the frame's psr (a debugger writes a
 * register, not the processor's mode). Both work on bytes because the
 * Pi1's ints have only 31 bits. *)
val plan9 : string -> int -> string
val into_frame : string -> string -> string
