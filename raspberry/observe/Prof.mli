(* This is a guest profile: the PC of every [every]-th instruction is
 * counted. The CPU loops call [tick] (Board.run and Pi4.turn; on a Pi4
 * only the AArch64 state is profiled, not the AArch32 programs).
 * [contents] gives the counts as lines "pc count", with the PC in
 * hexadecimal and the most sampled PC first, for
 * kernels/9pi/tests/perf/pcprof.py to map to a kernel's functions.
 *
 * It is mini-qemu's -prof FILE (docs/manuals/mini-qemu.md, section
 * 4.5), the first of plan_monitor.md's counters. It found that 38% of
 * mini-9pi's time drawing its console went to __aeabi_idivmod, because
 * the Pi1 has no divide instruction (docs/notes/notes_performance.md,
 * case 1). It is off by default, and then its cost is one test of [on]
 * per instruction.
 *
 * design:
 * Profiling by sampling means looking now and then at where the
 * program is. That says where its time goes, with no change to the
 * program, and at a cost chosen by how often one looks. Unix's prof
 * did it from a clock interrupt, with the kernel adding one to a
 * histogram of pcs. gprof (Graham, Kessler and McKusick, 1982) added
 * who called whom. An emulator is the best place for it. The guest is
 * not disturbed at all, not even by the interrupt; the kernel itself
 * can be profiled while its interrupts are off; and because it counts
 * instructions and not time, two runs give the same profile. What it
 * cannot say is what a real board's caches and memory would add. *)

val on : bool ref
val start : every:int -> unit
val tick : int -> unit
val contents : unit -> string
