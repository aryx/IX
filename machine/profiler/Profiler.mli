(* mini-prof: where a program's instructions went, function by function
 * (docs/plans/plan_profiler.md). It reads a profile, every instruction's
 * address and how many times it ran (mini-5i -prof, or mini-qemu -prof
 * for a whole system, there one in 1024), and the link's map of the
 * program (mini-ld -map: each function's address), and prints the
 * functions with the most instructions, with their share.
 *
 *     mini-5i -prof walk.prof doom -dump-frame 31 f.ppm -script up:1-31
 *     mini-prof walk.prof doom.map
 *
 *     1,234,567,890 instructions
 *              count      %  function
 *        234,567,890   19.0  f19_draw_column<>
 *        ...
 *
 * A count goes to the last function at or before its address. A name is
 * mini-ml's (f19_draw_column: the 19th function of its unit; <>, one
 * local to its file) or the C's and the runtime's (ml_alloc, copy<>).
 *
 * With -diff base, a profile of a shorter run is taken off first: the
 * same program stopped before what is measured (mini-doom's start and a
 * frame, against the start and 31), so that what is left is the frames
 * alone. Counting every instruction, and not sampling a clock, makes two
 * runs of the same program give the same counts: the difference is
 * exact.
 *
 * Where it stands: tiny-prof's twin (tiny/TinyProfiler: tiny-machine's
 * profiles, tiny-linker's maps), for m-ix's tools; it does what
 * machine/tests/profile.sh did from mini-5i -t's trace, a line of text
 * an instruction (a thousand million of them for mini-doom's start),
 * and kernels/9pi/tests/perf/pcprof.py did for mini-qemu's.
 *
 * history:
 * Unix's prof (1973) read mon.out, a histogram of the program counter
 * sampled at each clock tick, which a program compiled with -p wrote at
 * its exit; gprof (Graham, Kessler and McKusick, 1982) added who called
 * whom. Plan 9 kept prof (a program compiled with -p counts its calls
 * and their time) and added tprof, a process's pcs sampled by the kernel
 * into /proc/n/profile and read by name. An emulator counting every
 * instruction, as here and as 5i's statistics did, needs nothing of the
 * program, and is not disturbed by itself. *)

val usage : string

val main : < Cap.argv ; Cap.stdout ; Cap.stderr ; Cap.open_in ; .. > -> int
