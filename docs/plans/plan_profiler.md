# Plan: mini-prof, a profiler for m-ix (`profilers/misc`)

The author (2026-10-22), once mini-doom moved on mini-9pi at 5 frames a
second and its profiling was to start: "we have a tiny-profile but we
can start work on a mini-profiler, that could help for this too";
"counting the instructions is also a good starting point", "and useful
for profiling"; "we can start a plan_profiler.md possibly, and
hopefully it can help optimizing this doom game and mini-ml and more";
"and also maybe reduce the time it takes to compile m-ix under m-ix
(3h right now)".

## The targets

1. **mini-doom's frame on mini-9pi**: 5 to 6 a second under QEMU, the
   view (mini-ml's code of the renderer) and the showing (the draw
   platform) about half each (`plan_doom.md`'s Status).
2. **mini-ml's code in general**: 4 to 5 times OCaml's on mini-doom's
   renderer, 2.6 to 27 on lib_crypto, 2.8 on the scheduler's pass
   (`plan_mini_toolchain_optimization.md`, whose candidates C, D, J,
   K, L are open). Every m-ix program is mini-ml's code.
3. **m-ix compiled under m-ix**: 3 hours today. mini-ml, mini-cc,
   mini-asm, mini-ld and mini-mk by mini-ml, on mini-9pi: what each
   costs, then where inside each.

## What there is

| the tool | what it says | its cost |
|---|---|---|
| `mini-5i -s` | a program's instructions, exactly | a run |
| `machine/tests/profile.sh` | by function, from `mini-5i -t`'s trace: a line of text an instruction | mini-doom's start, a thousand million instructions: most of an hour |
| mini-qemu `-prof F`, `kernels/9pi/tests/perf/pcprof.py`, `steady.sh` | a whole system's pcs, one in 1024, by the kernel's functions or one program's | Python, one program at a time |
| tiny-prof (`tiny/TinyProfiler`) | tiny-machine's profile by tiny-linker's maps, the kernel's and the programs' apart, `-diff` | t-ix's only |
| the meters (`stats=on`, `Browser_profile`) | a program's parts, in ms | a program's own |

`docs/notes_profiling_techniques.md` has them side by side.

## Decisions

1. **Count, do not sample**, for a program alone: every instruction's
   address counted by the emulator, written once at the end. Two runs
   give the same counts, so a difference of two runs is exact (`-diff`:
   mini-doom's start and 31 frames, less its start and one). mini-qemu
   keeps its one in 1024 (a system runs for minutes).
2. **One format**: lines `pc count`, hexadecimal pc, mini-qemu's
   already. mini-prof reads mini-5i's and mini-qemu's alike.
3. **The link's map names the functions** (`mini-ld -map`'s `address
   name` lines, which every program built by the mkfiles has beside it;
   or `mini-ld -v`'s listing): the names cannot disagree with what ran.
4. **mini-prof is m-ix's program**: OCaml that mini-ml compiles, no
   Python (pcprof.py and profile.sh's own are to go), so that it can run
   on mini-9pi too.

## Stages

1. **Counts and functions** (done 2026-10-22): `mini-5i -prof file`;
   `mini-prof [-n count] [-diff base] profile file.map...`.
2. **A function's instructions** (`mini-prof -a name`): the hot
   function's instructions, each with its count, disassembled
   (Show_arm32, Show_arm64: the program's text read from the a.out or
   the ELF). What a back end's change is decided on: which loads and
   stores a loop's body has, which checks.
3. **Callers** (gprof's question): the calls counted by mini-5i (a
   branch with link: from where, to where), and each function's
   instructions with those of what it calls; `ml_alloc`, the collector
   and `caml_input` charged to who asks for them.
4. **mini-qemu's profiles by process**: the kernel's and each program's
   instructions apart (Plan 9's programs are all linked at the same
   address: the process known by the MMU's context), the maps of each;
   tiny-prof's `-k` and `-u`. pcprof.py and steady.sh then go.
5. **On mini-9pi itself** (later, the author's to decide): Plan 9's
   tprof, the kernel sampling a process's pc at each clock tick into
   `/proc/n/profile`, mini-prof reading it: a profile on the real Pi 1,
   its caches and memory in it.

Then the targets, in order: mini-doom's frame (its renderer and the
draw platform), what it finds in mini-ml's code, then m-ix built under
m-ix (each tool's share of the 3 hours, then inside the slowest).

## Status

2026-10-22: stage 1 done. `mini-5i -prof` counts by the trace's hook
(no change to the loop: off, its cost is the same test as before);
on, mini-5i is 1.8 times slower (mini-doom's start, 983 million
instructions: 61 s, 109 counted). `mini-prof`: 110 lines, built by
dune and by mini-mk (`profilers/misc`).

mini-doom on 32-bit arm Linux (`_mk/5`, the ppm platform, scale=2,
640 by 400), `-diff` of 31 frames walking and 1: 43 million
instructions a frame. `to_rgba` 30% (the palette's bytes made RGBA,
about 50 instructions a pixel), the collector about 20% (`copy` 11.4,
`move_bytes` 5.1, `ml_alloc` 2.1, `collect` 1.3: the WAD's data copied
at each collection), `map_plane` 9.5, `draw_column` 5.6 (called through
`ml_curry10_*`, a closure an argument past the registers), `obj_block`
5.1 (a block of more than 4 fields made by a call into C, `Lower.block`).

Found by it, fixed: the runtime's `caml_input` copied the channel's
buffer by a call of `getc_chan` a byte; now at once by `move_bytes`.
mini-doom's start, 651 million instructions, 568 now, the same picture;
every program reading files gains (m-ix built under m-ix). Its test:
`languages/ml/tests/runtime/input.ml`.

Next, mini-ml's, by the profile: blocks of more than 4 fields allocated
inline; known functions of more than 7 parameters called directly; stage
2 to see a per-pixel loop's instructions; the collector (a generational
one, or big long-lived data out of the copied heap). Not yet profiled:
scale=1 (mini-9pi's), m-ix built under m-ix.
