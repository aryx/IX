(* A guest profile: every [every]-th instruction's PC counted, the CPU
 * loops calling [tick] (Board.run, Pi4.turn: the AArch64 state only,
 * not a Pi4's AArch32 programs). [contents] gives the counts as lines
 * "pc count" (hexadecimal PC, the most sampled first), for
 * kernels/9pi/tests/perf/pcprof.py to map to a kernel's functions.
 *
 * mini-qemu's -prof FILE (docs/manuals/mini-qemu.md, section 4.5): the
 * first of plan_monitor.md's counters. It found that 38% of mini-9pi's
 * time drawing its console went to __aeabi_idivmod, the Pi1 having no
 * divide instruction (docs/notes_performance.md, case 1). Off by
 * default: then the cost is one test of [on] per instruction. *)

val on : bool ref
val start : every:int -> unit
val tick : int -> unit
val contents : unit -> string
