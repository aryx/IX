(* mini-prof: shows where a program's instructions went, function by
 * function (docs/plans/plan_profiler.md). It reads a profile, which
 * gives the address of every instruction and how many times it ran
 * (from mini-5i -prof, or from mini-qemu -prof for a whole system,
 * where one instruction in 1024 is counted). It also reads the link's
 * map of the program (from mini-ld -map, which gives each function's
 * address). It prints the functions that ran the most instructions,
 * with their share.
 *
 *     mini-5i -prof walk.prof doom -dump-frame 31 f.ppm -script up:1-31
 *     mini-prof walk.prof doom.map
 *
 *     1,234,567,890 instructions
 *              count      %  function
 *        234,567,890   19.0  f19_draw_column<>
 *        ...
 *
 * A count goes to the last function at or before its address. A name
 * is either mini-ml's (f19_draw_column is the 19th function of its
 * unit, and <> marks one that is local to its file) or a name from the
 * C code and the runtime (ml_alloc, copy<>).
 *
 * With -a name, it prints one function's instructions instead, each
 * with its count. They are read from the program beside the map (doom
 * for doom.map, which is an ELF, arm32 or arm64, or a Plan 9 a.out)
 * and printed by mini-5i's decoder, the way objdump prints them. This
 * is what you look at to decide a change in a back end.
 *
 *          count  address  instruction
 *      1,926,000    5acd0  ldr	r1, [sl, #-84]      a loop's bound and its
 *      1,926,000    5acd4  ldr	r2, [sl, #-88]      index, from the stack
 *      1,926,000    5acd8  cmp	r2, r1              at each turn
 *
 * With -diff base, the profile of a shorter run is subtracted first.
 * That run is the same program stopped before what is measured
 * (mini-doom's start and one frame, against the start and 31 frames),
 * so that what is left is the frames alone. Because every instruction
 * is counted, instead of sampling a clock, two runs of the same
 * program give the same counts, so the difference is exact.
 *
 * Where it stands: it is the twin of tiny-prof (tiny/TinyProfiler,
 * which reads tiny-machine's profiles and tiny-ld's maps), for m-ix's
 * tools. It does what machine/tests/profile.sh did from mini-5i -t's
 * trace, which has a line of text for each instruction (a thousand
 * million of them for mini-doom's start), and what
 * kernels/9pi/tests/perf/pcprof.py did for mini-qemu's.
 *
 * cs-history:
 * Unix's prof (1973) read mon.out, a histogram of the program counter
 * sampled at each clock tick, which a program compiled with -p wrote at
 * its exit. gprof (Graham, Kessler and McKusick, 1982) added who called
 * whom. Plan 9 kept prof (a program compiled with -p counts its calls
 * and their time) and added tprof, where the kernel samples a process's
 * pcs into /proc/n/profile and tprof reads them by name. An emulator
 * that counts every instruction, as here and as 5i's statistics did,
 * needs nothing from the program, and does not disturb what it
 * measures. *)

val usage : string

val main : < Cap.argv ; Cap.stdout ; Cap.stderr ; Cap.open_in ; .. > -> int
