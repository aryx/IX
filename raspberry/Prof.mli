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
 * default: then the cost is one test of [on] per instruction.
 *
 * design:
 * Profiling by sampling: where the program is, looked at now and
 * then, says where its time goes, with no change to the program and
 * at a cost chosen by how often one looks. Unix's prof did it from
 * a clock interrupt, the kernel adding one to a histogram of pcs;
 * gprof (Graham, Kessler and McKusick, 1982) added who called whom.
 * An emulator is the best place for it: the guest is not disturbed
 * at all, not even by the interrupt, the kernel itself can be
 * profiled with its interrupts off, and counting instructions and
 * not time makes two runs give the same profile. What it cannot
 * say is what a real board's caches and memory would add. *)

val on : bool ref
val start : every:int -> unit
val tick : int -> unit
val contents : unit -> string
