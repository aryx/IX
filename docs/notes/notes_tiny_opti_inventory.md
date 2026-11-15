# t-IX's optimizations, and what each one is worth

The twin of [notes_opti_inventory.md](notes_opti_inventory.md) (m-ix's
graphics and mini-ml) for t-IX: tiny-machine, tiny-kernel, tiny-ml and
the tiny programs. Started 2026-10-27 (the author, after play's WAV
was made to keep up: "maybe we can start a notes_tiny_opti_inventory.md
like we did for mix").

Scope: tiny/ from 2026-10-08 to 2026-10-27, then T14 to T21, the
steps of plans/done/plan_tiny_self_speed.md (2026-11-13 to 15, make
self 50 min 24 s to 5 min 50 s), each measured against the one before
it. Sources: the commit messages (each row gives its commit), the
code's old: and opti: comments and switches. Every number is copied
from the commit with the setting it gives, except T12 and T13's,
measured for this note. Not yet gathered: the tiny-as side, the tiny
programs' own
algorithms (TinyBrowser, TinyOffice), and the second pass every row
deserves (each gain measured alone again, on today's tree).

How it is measured: instructions, counted by tiny-machine -prof and
read by tiny-prof (by function, the kernel's -k map and a program's
-u map), or the host's seconds for a fixed count of the machine's
instructions (tests/TinyMachine_bench.sh: a recorded session, natively
and under node). A machine's run is the same instructions every time:
a profile is exact, and a change that should not change behaviour is
checked by the recorded sessions' screens and sounds (TinyKernel's
make check, frames and WAVs compared byte for byte).

Two budgets matter. The host's: with a window, tiny-machine holds the
machine to 20 million instructions a second (the web page to 8); a
host that runs fewer falls behind, and the sound comes in gaps. The
machine's: what a program needs a second of machine time, whatever the
host.

## Summary table

| # | Name | Where (module, commit) | Gain recorded | LOC | Switch |
|---|---|---|---|---|---|
| T1 | Batched ticks: after a tick that looks, bare steps to the next moment that can change something | TinyMachineDevices `ticks`, 90f1fc38 | natively 15.2 to 22.0 M instr/s; node 6.8 to 8.1 | (part of +222 -15) | `batched` |
| T2 | No closure at each load and step | TinyMachineCPU `load`, `set`; 90f1fc38 | node 4.5 to 5.2 M instr/s | (same) | none (old: comments) |
| T3 | Decoded words kept, by the word | TinyMachineCPU `keep_decoded`, 90f1fc38 | node 6.8 to 8.1; natively 21.3 to 22.0 | (same) | `keep_decoded` |
| T4 | The scheduler idle: interrupts counted, nothing retried but by a key, the mouse or the alarm | KScheduler `idle`, 56354ee0 | "a quarter of the instructions of a machine where nothing happened" | (part of the windows' step) | none (old: comment) |
| T5 | tiny-ml: `String.length` and `s.[i]` inline; an ML program's heap at its full size | TinyML's -tm back end, mlsys.c; cbc0b9cc | the browser reading OCaml's Wikipedia page 447M to 356M to 233M instructions (collector 26% to 2%) | +79 -18 | none |
| T6 | Text drawn in one call (glyphs), lines as rectangles, rows copied four words a turn | KGraphics, kdraw.s, TinyLibDraw, www; 539519f2 | a page down 3.56 s to 0.93 s of the host; ~5.4M instructions | +240 -47 | the old path kept for the rest |
| T7 | tiny-ml's names in hash tables, keywords by table | TinyML, fe58f4b3 | TinyML.ml compiled on tiny-kernel 11 min to 171 s (202 with Printf) | +390 -230 | none (old: comments) |
| T8 | SHA-1 in C | TinyMLRuntime/core.c, a2da2e93 | a digest of 141 KB 770M to 77M instructions; 3.8 of the self-build's 5.5 hours | (part of +193 -79) | none |
| T9 | Marshal in C, interfaces marshalled; a function's text into one buffer | core.c, TinyML; 8885624d | Troff's unit 16.7M to 7.7M instructions (host); a unit of one line 3.2 s to 2.2 s on tiny-kernel | +550 -135 | none |
| T10 | `read_file`: pieces read, then copied once | TinyLibGUI, 3e5c8a7f | a WAV of 141 KB was 85M instructions (600 a byte) | small | none (old: comment) |
| T11 | The machine's speed a setting, 20 M with a window | TinyMachine, kentry.s; 29662089 | not a saving: the machine 2.5 times faster for a person watching, the programs' pace by ticks kept | +157 -54 | `-rate n` |
| T12 | `wfi`: the kernel idle asleep, the time added at once | TinyMachineDevices `extra`, `tick`, `ticks`; kentry.s's k_idle1 (2026-10-27; first as a guess from a jump to itself, `idle_skipped`, 51096869) | play's run (boot, the 6.4 s WAV, sleep 2: 9.6 s of machine time) at -rate 20: 11.0 s of the host to 8.7 | +45 | `batched` (false: each tick, asleep or not) |
| T13 | A sound's write that waits woken when the ring has room, not every 10 ms | KIO `Voice`, KDevices `speak` (2026-10-27) | the same run: 135M busy instructions to 88M; with T12 6.1 s of the host | +18 -10 | none (old: comment) |
| T14 | tiny-machine of dune's release profile for the long runs (no -opaque) | TinyKernel/Makefile, 4f8252ab | make self 50 min 24 s to 40 min 22 s | +18 | MACHINE= |
| T15 | A name looked up in the directory's blocks, no string made | KFS `fs_lookup`, bb473aa2 | make self 40:22 to 28:11; instructions 100.8 G to 82.4 G | +38 -2 | none (old: comment) |
| T16 | tiny-cc: scalar variables in registers, operands read in place, immediates | TinyC Lower, Machine; 99b9ce29, fdf7a9c6 | a copy loop 31 to 11 instructions a byte; make self 28:11 to 19:21 | +433 -76 | none (old: comments) |
| T17 | tiny-ml: a block allocated inline, ml_alloc only to collect | TinyML Machine `alloc`, ml.c `ml_heap`; 8545b4e1 | self-quick 39.3 s to 35.8 s; make self 19:21 to 18:06 | +101 -13 | `alloc_c` for big blocks |
| T18 | tiny-machine: memory reached directly in a stretch's window | TinyMachineCPU `step_in`, TinyMachineDevices `window`; 0838a492 | self-quick 1.47x; the bench natively 1.5 to 1.6x, under node 1.2 to 1.6x; make self 18:06 to 13:13 | +73 -10 | `direct` |
| T19 | The scheduler: last in one pass or none, a process's gone | KScheduler `last`, KProcs; 1d6eacf3 | make self 13:13 to 12:12 | (part of +147 -33) | none (old: comment) |
| T20 | k_copy eight words a turn; rc spawning a simple command, a mask of the descriptors | kcopy.s, TinyShell `launch`, KCalls `sys_spawn`; 1d6eacf3 | make self 12:12 to 11:50 | (same) | fork and exec kept |
| T21 | Cores in parallel: idle ones blocking, core 0 dozing, another core's slice 8 ticks | TinyMachine.ml, KScheduler `give`; 3d32bc3d | make self-cores 7:49 to 5:50 (host CPU 1863 s to 885 s) | +116 -18 | SELF_CORES= |

## Worth it?

Kept, the gain large and measured:
- T1 and T3: the host's speed, every program's. T1 is what lets a
  2.2 GHz Neoverse hold a window at 20 million.
- T5, T7, T8, T9: tiny-ml's programs and tiny-kernel building itself.
- T13: ten lines, a third of play's instructions.

To measure again:
- T12 on the recorded sessions: their machine is the same (the
  screens and sounds are byte for byte), but their host time was not
  timed. It saves what a machine idles, so a busy program gains
  nothing; play gains its ~13% of idle and the sleep after. Worth it
  apart from speed: the kernel says it idles, as on a real machine.
- T2 and T3 natively on today's tree: their numbers are node's.

## Details

**T12. wfi, the kernel idle asleep.** tiny-kernel waited in `k_idle1:
j k_idle1`, interrupts on, and tiny-machine stepped it, a jump at a
time, 20 million a second with a window: the host's speed spent on
nothing. 51096869 skipped such a stretch by recognizing the pattern (a
jump to itself, in the kernel): exact, but a guess from the kernel's
code that another shape of idle loop would silently lose. Now the
machine has `wfi` (0x37, the supervisor's), ARM's and RISC-V's
instruction, x86's `hlt`: the core sleeps until an interrupt enabled
in `ie` is pending, and a calm stretch asleep is only time, added at
once. k_idle1 and the other cores' wait are `wfi` then a jump back.
`spent`'s idle is now the time asleep (TinyMachine_tests/cores.s's
wait0 a `wfi` too). The machine after a sleep is the one the loop of
jumps left: korobeiniki.wav's sound and every recorded session the
same bytes. Measured: 11.0 s to 8.7 s of the host, then 6.45 s with
T13 and the wfi. A profile (-prof) counts no instruction while asleep.
v0 and t6 (TinyKernel/steps/) still idle in a jump to itself, stepped.

**T13. The sound's write woken when it fits.** play writes its WAV
2,048 samples a write; the kernel takes a write whole when it fits in
the ring (8,192 samples, a second ahead of the speaker), else the
process waits. The alarm was set 4 ticks (10 ms) on, and each look
copied the write from the process (`k_string`) and parsed it again
(`sounds`'s `String.sub`): 2,048 samples need 256 ms of room, so a
block was copied about 25 times. `speak` now says how many samples are
missing, and the alarm is set to when the speaker will have played
them (20 a tick of 2.5 ms). Profile of the same run at -rate 20:
`k_string` 26.9M to 5.6M, the kernel's `ml_string_sub` 31.6M to 6.9M;
busy instructions 135M to 88M. The song alone is then about 68M
instructions for 6.4 s, 10.6 million a second: half of the window's
20, where it was about 17.

What remains in play's profile (88M, 2026-10-27): play's own `piece`
and the read of the file (`u_read`, the program's `ml_string_sub`,
`ml_bytes_blit_string`: the 141 KB read before the first sound), the
kernel's `add_samples` (a peekb and a pokeb a sample) and k_string.

## The baseline of 2026-11-14

Before plan_tiny_self_speed.md's steps (its step 0, at c45e5910, with
bin/tiny-machine in dune's dev profile): make self's session took 50
minutes 24 seconds of the host, and its first build, most of that, took
100.8 G instructions of the machine, 41% of them in the kernel (fs_lookup's strings: about a
quarter of the whole) and 59% in the programs (the runtime's
`ml_alloc` alone 7%). The plan has the phases and the profile.
tests/TinyMachine_bench.sh, the same day, in the machine's instructions
a second (wfi's sleep included): paint 113.8 M natively and 29.8 M
under node, emacs 171.7 and 49.8, windows 124.4 and 39.7, office 87.3
and 27.4, tetris 59.2 and 19.6.

## Open questions

1. T12's gain on the recorded sessions (tests/TinyMachine_bench.sh)
   not measured.
2. T4's number is the commit's words, not a measure kept.
3. T1 to T3 were measured together on 2026-10-10; T1's and T3's own
   numbers are each "measured alone" in the commit, T2's under node
   only.
